--!strict
-- One guardian per biome, driven by a single throttled server loop (spec §6, A9/A10).
--   Patrol  -> walk between the biome's patrol points.
--   Detect  -> nearest player in the biome within DetectRange (2.5x inside a danger zone),
--              never inside the safe zone. That player alone is warned and targeted.
--   Chase   -> PathfindingService path to the target (led by Predict seconds of velocity),
--              recomputed every RecomputeSeconds off-thread; direct move while no path.
--   Lose    -> target outside the leash, inside the safe zone, out of the biome, gone, or the
--              guardian made no headway for StuckSeconds. Then a short cooldown, then patrol.
--   Catch   -> teleport the player home and clear ONLY their unbanked expedition bag.
-- Guardians in biomes with no players skip their update entirely (sleep).
-- A seasonal event may add one extra guardian over its own zone while the event is active.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Config = require(ReplicatedStorage.Shared.Config)
local GuardianDefs = require(ReplicatedStorage.Shared.Guardians)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local EventDefs = require(ReplicatedStorage.Shared.Events)
local Biomes = require(script.Parent.Biomes)
local Data = require(script.Parent.Data)
local Expedition = require(script.Parent.Expedition)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)
local GuardianRig = require(script.Parent.World.Builders.GuardianRig)

local G = Config.Guardian

type State = "Patrol" | "Chase" | "Cooldown"
type Guardian = {
	def: GuardianDefs.Guardian,
	zone: string,
	center: Vector3,
	patrolPts: { Vector3 },
	danger: { { center: Vector3, radius: number } },
	inRegion: (Vector3) -> boolean,
	inSafe: (Vector3) -> boolean,
	clamp: (Vector3) -> Vector3,
	model: Model,
	path: Path,
	pos: Vector3,
	facing: Vector3,
	state: State,
	patrolIdx: number,
	target: Player?,
	waypoints: { Vector3 },
	wpIdx: number,
	lastCompute: number,
	computing: boolean,
	stuckFrom: Vector3,
	stuckAt: number,
	cooldownUntil: number,
	sleeping: boolean,
	alert: Sound,
}

type Visitor = { player: Player, pos: Vector3, root: BasePart }

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

-- Keeps the guardian inside its biome walls even on a direct (non-path) move.
local function clampToBiome(info: Biomes.BiomeInfo, pos: Vector3): Vector3
	local lp = info.cf:PointToObjectSpace(pos)
	local half = Config.Biome.Size / 2 - 4
	local clamped = Vector3.new(math.clamp(lp.X, -half, half), 0, math.clamp(lp.Z, -half, half))
	local world = info.cf:PointToWorldSpace(clamped)
	return Vector3.new(world.X, groundY(), world.Z)
end

-- Moves toward `goal` at `speed`; returns true once within 1.5 studs.
local function step(g: Guardian, goal: Vector3, speed: number, dt: number): boolean
	local delta = flat(goal - g.pos)
	local dist = delta.Magnitude
	if dist < 1.5 then
		return true
	end
	local dir = delta / dist
	g.pos = g.clamp(g.pos + dir * math.min(dist, speed * dt))
	g.facing = dir
	place(g)
	return false
end

local function inDanger(g: Guardian, pos: Vector3): boolean
	for _, zone in g.danger do
		if flat(pos - zone.center).Magnitude <= zone.radius then
			return true
		end
	end
	return false
end

local function setDanger(player: Player, on: boolean, g: Guardian?)
	if player.Parent then
		Net.fire("Danger", player, on, if g then g.def.Name else nil)
	end
end

local function lose(g: Guardian, now: number)
	local target = g.target
	if target then
		setDanger(target, false)
	end
	g.target = nil
	g.waypoints = {}
	g.state = "Cooldown"
	g.cooldownUntil = now + G.CooldownSeconds
end

local function startChase(g: Guardian, v: Visitor, now: number)
	g.state = "Chase"
	g.target = v.player
	g.waypoints = {}
	g.wpIdx = 1
	g.lastCompute = -math.huge
	g.stuckFrom = g.pos
	g.stuckAt = now
	g.alert:Play()
	setDanger(v.player, true, g)
end

local function catch(g: Guardian, player: Player, now: number)
	local lost = Expedition.lose(player)
	local character = player.Character
	if character then
		local home = Plots.spawnCFrame(player) or Biomes.HubSpawn
		character:PivotTo(home + Vector3.new(0, 3, 0))
	end
	lose(g, now)
	Net.notify(player, if lost > 0
		then `{g.def.Name} caught you! You dropped {lost} unbanked seed{if lost == 1 then "" else "s"}.`
		else `{g.def.Name} caught you! Your bag was empty, so nothing was lost.`, "error")
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
		lose(g, now)
		return
	end
	local tpos = root.Position
	if not g.inRegion(tpos) or g.inSafe(tpos)
		or flat(tpos - g.center).Magnitude > g.def.LeashRange then
		lose(g, now)
		return
	end
	if flat(tpos - g.pos).Magnitude <= g.def.CatchRange then
		catch(g, target, now)
		return
	end

	local goal = g.clamp(tpos + flat(root.AssemblyLinearVelocity) * g.def.Predict)
	if not g.computing and now - g.lastCompute >= g.def.RecomputeSeconds then
		g.lastCompute = now
		task.spawn(computePath, g, goal, target)
	end
	local wp = g.waypoints[g.wpIdx]
	if wp then
		if step(g, wp, g.def.ChaseSpeed, dt) then
			g.wpIdx += 1
		end
	else
		step(g, goal, g.def.ChaseSpeed, dt)
	end

	if (g.pos - g.stuckFrom).Magnitude >= G.StuckMinProgress then
		g.stuckFrom = g.pos
		g.stuckAt = now
	elseif now - g.stuckAt > G.StuckSeconds then
		lose(g, now)
	end
end

local function patrol(g: Guardian, dt: number)
	local pts = g.patrolPts
	if step(g, pts[g.patrolIdx], g.def.WalkSpeed, dt) then
		g.patrolIdx = g.patrolIdx % #pts + 1
	end
end

local function detect(g: Guardian, visitors: { Visitor }, now: number)
	local best: Visitor? = nil
	local bestD = math.huge
	for _, v in visitors do
		if not g.inSafe(v.pos) then
			local d = flat(v.pos - g.pos).Magnitude
			local range = if inDanger(g, v.pos) then g.def.DetectRange * 2.5 else g.def.DetectRange
			if d <= range and d < bestD then
				best, bestD = v, d
			end
		end
	end
	if best then
		startChase(g, best, now)
	end
end

local function tick(dt: number)
	local now = os.clock()
	local all: { Visitor } = {}
	for _, player in Players:GetPlayers() do
		local root = Biomes.rootOf(player)
		if root and Data.isLoaded(player) then
			table.insert(all, { player = player, pos = root.Position, root = root })
		end
	end
	local active = table.clone(guardians)
	if eventGuardian then
		table.insert(active, eventGuardian)
	end
	for _, g in active do
		local visitors: { Visitor }? = nil
		for _, v in all do
			if g.inRegion(v.pos) then
				visitors = visitors or {}
				table.insert(visitors :: { Visitor }, v)
			end
		end
		if g.state == "Chase" then
			g.sleeping = false
			chase(g, dt, now)
		elseif not visitors then
			g.sleeping = true
		else
			g.sleeping = false
			patrol(g, dt)
			if g.state == "Cooldown" and now >= g.cooldownUntil then
				g.state = "Patrol"
			end
			if g.state == "Patrol" then
				detect(g, visitors, now)
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

local function spawn(def: GuardianDefs.Guardian, folder: Instance, fields: {
	zone: string, center: Vector3, patrolPts: { Vector3 }, danger: { { center: Vector3, radius: number } },
	inRegion: (Vector3) -> boolean, inSafe: (Vector3) -> boolean, clamp: (Vector3) -> Vector3,
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
	local g: Guardian = {
		def = def, zone = fields.zone, center = fields.center, patrolPts = fields.patrolPts, danger = fields.danger,
		inRegion = fields.inRegion, inSafe = fields.inSafe, clamp = fields.clamp, model = model,
		path = PathfindingService:CreatePath({ AgentRadius = 2 * def.Scale, AgentHeight = 6 * def.Scale, AgentCanJump = false }),
		pos = pos, facing = Vector3.new(0, 0, -1), state = "Patrol", patrolIdx = 2,
		target = nil, waypoints = {}, wpIdx = 1, lastCompute = 0, computing = false,
		stuckFrom = pos, stuckAt = 0, cooldownUntil = 0, sleeping = true, alert = alert,
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
			lose(old, os.clock())
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
	local hubSafe = Config.Bank.HubRadius
	eventGuardian = spawn(def, folderOf(nil), {
		zone = eventId, center = c, patrolPts = pts, danger = {},
		inRegion = function(pos)
			return flat(pos - c).Magnitude <= radius
		end,
		inSafe = function(pos)
			return flat(pos).Magnitude <= hubSafe
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

function GuardianAI.start(worldFolder: Instance)
	local folder = folderOf(worldFolder)
	for _, biome in BiomeData.List do
		local def = GuardianDefs.ByBiome[biome.Id]
		local info = Biomes.info(biome.Id)
		if def and info then
			local id = biome.Id
			table.insert(guardians, spawn(def, folder, {
				zone = id, center = info.cf.Position, patrolPts = info.skeleton.patrol, danger = info.skeleton.danger,
				inRegion = function(pos)
					return Biomes.inRegion(id, pos)
				end,
				inSafe = function(pos)
					return Biomes.inSafeZone(id, pos)
				end,
				clamp = function(pos)
					return clampToBiome(info, pos)
				end,
			}))
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		local active = table.clone(guardians)
		if eventGuardian then
			table.insert(active, eventGuardian)
		end
		for _, g in active do
			if g.target == player then
				lose(g, os.clock())
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
