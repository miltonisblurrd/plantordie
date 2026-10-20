--!strict
-- One guardian per biome, driven by a single throttled server loop (spec §6).
--   Patrol  -> walk the biome's patrol points at PatrolFactor x chase speed. Ignores everyone.
--   Chase   -> started only by picking up a seed from this guardian's biome; targets that carrier
--              alone. PathfindingService path to the target (led by Predict seconds of velocity),
--              recomputed every RecomputeSeconds off-thread; direct move while no path. May leave
--              the biome. Ends when the carrier banks, drops, reaches the hub safe area, leaves,
--              or after MaxChaseSeconds.
--   Return  -> walk back into the biome, then patrol.
--   Catch   -> knockback + stun, the seed drops where the carrier stood, no catches for
--              CooldownSeconds. A new chase needs a new pickup.
-- Chase speed = Speed.guardianSpeedFor(biome RecommendedSpeed). Day/night has no effect.
-- Patrolling guardians in biomes with no players skip their update (sleep); chasing or
-- returning ones never sleep. A seasonal event may add one guardian over its own zone, which
-- chases carriers of seeds whose origin is that event id.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Config = require(ReplicatedStorage.Shared.Config)
local GuardianDefs = require(ReplicatedStorage.Shared.Guardians)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Speed = require(ReplicatedStorage.Shared.Speed)
local EventDefs = require(ReplicatedStorage.Shared.Events)
local Biomes = require(script.Parent.Biomes)
local Carry = require(script.Parent.Carry)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)
local Treadmill = require(script.Parent.Treadmill)
local GuardianRig = require(script.Parent.World.Builders.GuardianRig)

local G = Config.Guardian

type State = "Patrol" | "Chase" | "Return"
type Guardian = {
	def: GuardianDefs.Guardian,
	zone: string, -- biome id or event id; matches Carry item origin
	patrolPts: { Vector3 },
	inRegion: (Vector3) -> boolean,
	clamp: (Vector3) -> Vector3,
	model: Model,
	path: Path,
	pos: Vector3,
	facing: Vector3,
	state: State,
	patrolIdx: number,
	chaseSpeed: number,
	patrolSpeed: number,
	target: Player?,
	chaseStartedAt: number,
	noCatchUntil: number,
	waypoints: { Vector3 },
	wpIdx: number,
	lastCompute: number,
	computing: boolean,
	stuckFrom: Vector3,
	stuckAt: number,
	sleeping: boolean,
	alert: Sound,
}

local GuardianAI = {}

local guardians: { Guardian } = {}
local eventGuardian: Guardian? = nil
local eventGuardianId: string? = nil
local rootFolder: Instance? = nil

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function groundY(): number
	return Config.World.GroundY + 0.1
end

local function place(g: Guardian)
	g.model:PivotTo(CFrame.lookAt(g.pos, g.pos + g.facing))
end

local function allGuardians(): { Guardian }
	local active = table.clone(guardians)
	if eventGuardian then
		table.insert(active, eventGuardian)
	end
	return active
end

-- Keeps a patrolling guardian inside its biome walls. Chase and return moves skip it.
local function clampToBiome(info: Biomes.BiomeInfo, pos: Vector3): Vector3
	local lp = info.cf:PointToObjectSpace(pos)
	local half = Config.Biome.Size / 2 - 4
	local clamped = Vector3.new(math.clamp(lp.X, -half, half), 0, math.clamp(lp.Z, -half, half))
	local world = info.cf:PointToWorldSpace(clamped)
	return Vector3.new(world.X, groundY(), world.Z)
end

local function inHubSafe(pos: Vector3): boolean
	return flat(pos - Biomes.HubSpawn.Position).Magnitude <= Config.Bank.HubRadius
end

-- Moves toward `goal` at `speed`; returns true once within 1.5 studs.
local function step(g: Guardian, goal: Vector3, speed: number, dt: number, free: boolean): boolean
	local delta = flat(goal - g.pos)
	local dist = delta.Magnitude
	if dist < 1.5 then
		return true
	end
	local dir = delta / dist
	local nextPos = g.pos + dir * math.min(dist, speed * dt)
	g.pos = if free then Vector3.new(nextPos.X, groundY(), nextPos.Z) else g.clamp(nextPos)
	g.facing = dir
	place(g)
	return false
end

local function endChase(g: Guardian, reason: string, knockback: Vector3?)
	local target = g.target
	g.target = nil
	g.waypoints = {}
	if g.state == "Chase" then
		g.state = "Return"
	end
	if target and target.Parent then
		Net.fire("Chase", target, "end", g.def.Name, reason, knockback)
	end
end

local function startChase(g: Guardian, player: Player, now: number): boolean
	if g.state == "Chase" and g.target ~= player then
		return false
	end
	g.state = "Chase"
	g.target = player
	g.chaseStartedAt = now
	g.waypoints = {}
	g.wpIdx = 1
	g.lastCompute = -math.huge
	g.stuckFrom = g.pos
	g.stuckAt = now
	g.sleeping = false
	g.alert:Play()
	Net.fire("Chase", player, "start", g.def.Name)
	return true
end

local function catch(g: Guardian, player: Player, root: BasePart, now: number)
	local away = flat(root.Position - g.pos)
	local dir = if away.Magnitude > 0.01 then away.Unit else g.facing
	local knock = dir * G.KnockbackHorizontal + Vector3.new(0, G.KnockbackUp, 0)
	g.noCatchUntil = now + G.CooldownSeconds
	local item = Carry.carried(player)
	endChase(g, "catch", knock)
	root.AssemblyLinearVelocity = knock
	Treadmill.stun(player, G.StunSeconds)
	Carry.drop(player, root.Position, "catch")
	if item then
		Net.notify(player, `{g.def.Name} caught you! You dropped your seed. Grab it before the timer runs out!`, "error")
	end
end

local function computePath(g: Guardian, goal: Vector3, target: Player)
	g.computing = true
	local from = g.pos
	local ok = pcall(function()
		g.path:ComputeAsync(from, goal)
	end)
	g.computing = false
	if g.target ~= target or g.state ~= "Chase" then
		return
	end
	if ok and g.path.Status == Enum.PathStatus.Success then
		local pts: { Vector3 } = {}
		for i, wp in g.path:GetWaypoints() do
			if i > 1 then
				table.insert(pts, wp.Position)
			end
		end
		g.waypoints = pts
		g.wpIdx = 1
	else
		g.waypoints = {}
	end
end

local function chase(g: Guardian, dt: number, now: number)
	local target = g.target
	local root = target and Biomes.rootOf(target)
	local humanoid = root and root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	if not target or not root or not target.Parent or (humanoid and humanoid.Health <= 0) then
		endChase(g, "lost")
		return
	end
	if not Carry.isCarrying(target) then
		endChase(g, "drop")
		return
	end
	if now - g.chaseStartedAt >= G.MaxChaseSeconds then
		endChase(g, "timeout")
		return
	end
	local tpos = root.Position
	if inHubSafe(tpos) then
		endChase(g, "safe")
		return
	end
	local plot = Plots.plotAt(tpos)
	if plot and plot == Plots.plotOf(target) then
		endChase(g, "bank")
		return
	end
	if now >= g.noCatchUntil and flat(tpos - g.pos).Magnitude <= g.def.CatchRange then
		catch(g, target, root, now)
		return
	end

	local lead = tpos + flat(root.AssemblyLinearVelocity) * g.def.Predict
	local goal = Vector3.new(lead.X, groundY(), lead.Z)
	if not g.computing and now - g.lastCompute >= g.def.RecomputeSeconds then
		g.lastCompute = now
		task.spawn(computePath, g, goal, target)
	end
	local wp = g.waypoints[g.wpIdx]
	if wp then
		if step(g, wp, g.chaseSpeed, dt, true) then
			g.wpIdx += 1
		end
	else
		step(g, goal, g.chaseSpeed, dt, true)
	end

	-- A path that makes no headway is dropped for a direct move; the chase itself goes on.
	if (g.pos - g.stuckFrom).Magnitude >= G.StuckMinProgress then
		g.stuckFrom = g.pos
		g.stuckAt = now
	elseif now - g.stuckAt > G.StuckSeconds then
		g.waypoints = {}
		g.stuckFrom = g.pos
		g.stuckAt = now
	end
end

local function patrol(g: Guardian, dt: number)
	local pts = g.patrolPts
	if step(g, pts[g.patrolIdx], g.patrolSpeed, dt, false) then
		g.patrolIdx = g.patrolIdx % #pts + 1
	end
end

local function returnHome(g: Guardian, dt: number)
	if step(g, g.patrolPts[g.patrolIdx], g.patrolSpeed, dt, true) then
		g.state = "Patrol"
	end
end

local function tick(dt: number)
	local now = os.clock()
	local positions: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local root = Biomes.rootOf(player)
		if root and Data.isLoaded(player) then
			table.insert(positions, root.Position)
		end
	end
	for _, g in allGuardians() do
		if g.state == "Chase" then
			g.sleeping = false
			chase(g, dt, now)
		elseif g.state == "Return" then
			g.sleeping = false
			returnHome(g, dt)
		else
			local seen = false
			for _, pos in positions do
				if g.inRegion(pos) then
					seen = true
					break
				end
			end
			g.sleeping = not seen
			if seen then
				patrol(g, dt)
			end
		end
	end
end

function GuardianAI.awakeCount(): number
	local n = 0
	for _, g in guardians do
		if not g.sleeping then
			n += 1
		end
	end
	return n
end

local function speedFor(def: GuardianDefs.Guardian): number
	local biome = BiomeData.ById[def.Biome]
	local recommended = def.RecommendedSpeed or (if biome then biome.RecommendedSpeed else 0)
	return Speed.guardianSpeedFor(recommended)
end

local function spawn(def: GuardianDefs.Guardian, folder: Instance, fields: {
	zone: string, patrolPts: { Vector3 }, inRegion: (Vector3) -> boolean, clamp: (Vector3) -> Vector3,
}): Guardian
	local start = fields.patrolPts[1]
	local pos = Vector3.new(start.X, groundY(), start.Z)
	local model = GuardianRig.build(def, CFrame.new(pos), folder)
	local alert = Instance.new("Sound")
	alert.Name = "Alert"
	alert.SoundId = Sounds.uri("GuardianWarning") or ""
	alert.Volume = 1
	alert.RollOffMaxDistance = 120
	alert.Parent = model.PrimaryPart
	local chaseSpeed = speedFor(def)
	local g: Guardian = {
		def = def, zone = fields.zone, patrolPts = fields.patrolPts,
		inRegion = fields.inRegion, clamp = fields.clamp, model = model,
		path = PathfindingService:CreatePath({ AgentRadius = 2 * def.Scale, AgentHeight = 6 * def.Scale, AgentCanJump = false }),
		pos = pos, facing = Vector3.new(0, 0, -1), state = "Patrol", patrolIdx = 2,
		chaseSpeed = chaseSpeed, patrolSpeed = chaseSpeed * G.PatrolFactor,
		target = nil, chaseStartedAt = 0, noCatchUntil = 0, waypoints = {}, wpIdx = 1, lastCompute = 0,
		computing = false, stuckFrom = pos, stuckAt = 0, sleeping = true, alert = alert,
	}
	place(g)
	return g
end

local function folderOf(worldFolder: Instance?): Instance
	local existing = rootFolder
	if existing and existing.Parent then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = worldFolder or workspace
	rootFolder = folder
	return folder
end

-- Spawns the guardian for `eventId` (if that event defines one) or removes the current one.
function GuardianAI.setEventGuardian(eventId: string?)
	local def = eventId and GuardianDefs.Event[eventId]
	local ev = eventId and EventDefs.ById[eventId]
	local zoneDef = ev and ev.Guardian
	if eventGuardianId == eventId and (eventGuardian ~= nil) == (def ~= nil) then
		return
	end
	local old = eventGuardian
	if old then
		if old.target then
			endChase(old, "lost")
		end
		old.model:Destroy()
		eventGuardian = nil
	end
	eventGuardianId = nil
	if not (def and zoneDef and eventId) then
		return
	end
	local c = Vector3.new(zoneDef.Center.X, 0, zoneDef.Center.Z)
	local radius = zoneDef.Radius
	local inner = radius * 0.6
	local pts = {}
	for i = 0, 3 do
		local a = i * math.pi / 2
		table.insert(pts, c + Vector3.new(math.cos(a) * inner, 0, math.sin(a) * inner))
	end
	eventGuardian = spawn(def, folderOf(nil), {
		zone = eventId, patrolPts = pts,
		inRegion = function(pos)
			return flat(pos - c).Magnitude <= radius
		end,
		clamp = function(pos)
			local d = flat(pos - c)
			if d.Magnitude > radius - 2 then
				d = d.Unit * (radius - 2)
			end
			return Vector3.new(c.X + d.X, groundY(), c.Z + d.Z)
		end,
	})
	eventGuardianId = eventId
end

function GuardianAI.eventGuardianCount(): number
	return if eventGuardian then 1 else 0
end

local function guardianFor(origin: string): Guardian?
	for _, g in allGuardians() do
		if g.zone == origin then
			return g
		end
	end
	return nil
end

function GuardianAI.start(worldFolder: Instance)
	local folder = folderOf(worldFolder)
	for _, biome in BiomeData.List do
		local def = GuardianDefs.ByBiome[biome.Id]
		local info = Biomes.info(biome.Id)
		if def and info then
			local id = biome.Id
			table.insert(guardians, spawn(def, folder, {
				zone = id, patrolPts = info.skeleton.patrol,
				inRegion = function(pos)
					return Biomes.inRegion(id, pos)
				end,
				clamp = function(pos)
					return clampToBiome(info, pos)
				end,
			}))
		end
	end

	Carry.onPickup(function(player, item)
		local g = guardianFor(item.origin)
		if g then
			startChase(g, player, os.clock())
		end
	end)
	Carry.onRelease(function(player, _item, reason)
		for _, g in allGuardians() do
			if g.target == player and g.state == "Chase" then
				endChase(g, reason)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, g in allGuardians() do
			if g.target == player then
				endChase(g, "lost")
			end
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(G.TickSeconds)
			local now = os.clock()
			tick(math.min(now - last, 0.5))
			last = now
		end
	end)
end

return GuardianAI
