--!strict
-- One guardian per biome (spec §6). Chasing guardians step every Heartbeat; patrol and return
-- run on a throttled TickSeconds loop. All decisions are server-side; the rig is server-owned
-- physics driven through AlignPosition, so clients see smooth interpolated motion.
--   Patrol  -> walk the biome's patrol points at PatrolFactor x baseline speed. Ignores everyone.
--   Chase   -> started only by picking up a seed from this guardian's biome; targets that carrier
--              alone. Runs straight at the target (led by Predict seconds of velocity) while it
--              has line of sight; when blocked, follows one PathfindingService path, recomputed
--              only when the target moves RepathDistance from the path's goal or the path stalls.
--              One path computes at a time server-wide. Speed ramps at Accel and facing turns
--              smoothly. No catch for StartGraceSeconds, and never without line of sight. May
--              leave the biome. Ends the moment the carrier enters the shared Safe Zone, or when
--              they bank, drop, leave, or after MaxChaseSeconds. A carrier who escaped to safety
--              and comes back into this guardian's biome still holding its seed is chased again.
--   Return  -> walk back into the biome, then patrol.
-- No guardian ever moves into the Safe Zone: every step is clamped at its boundary.
--   Catch   -> knockback + stun, the seed drops where the carrier stood, no catches for
--              CooldownSeconds. A new chase needs a new pickup.
-- Chase speed follows the carrier: a speed stat above the biome's RecommendedSpeed outruns the
-- guardian (OutrunFactor x their carrying walk speed); at or below it, the guardian is faster
-- (CatchFactor). Patrol runs at Speed.guardianSpeedFor(RecommendedSpeed). Day/night has no effect.
-- Patrolling guardians in biomes with no players skip their update (sleep); chasing or
-- returning ones never sleep. A seasonal event may add one guardian over its own zone, which
-- chases carriers of seeds whose origin is that event id.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local SafeZone = require(script.Parent.SafeZone)
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
	recommended: number,
	speed: number,
	chaseSpeed: number,
	patrolSpeed: number,
	alignPos: AlignPosition,
	alignOri: AlignOrientation,
	los: boolean,
	losAt: number,
	lastGoal: Vector3,
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
-- Carriers whose chase ended at the Safe Zone, keyed to the guardian zone they escaped from.
local escaped: { [Player]: string } = {}
local pathBusy = false
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.IgnoreWater = true

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function groundY(): number
	return Config.World.GroundY + 0.1
end

local function place(g: Guardian)
	g.alignPos.Position = g.pos
	g.alignOri.CFrame = CFrame.lookAt(Vector3.zero, g.facing)
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
	local halfX = Config.Biome.Width / 2 - 4
	local halfZ = Config.Biome.Size / 2 - 4
	local clamped = Vector3.new(math.clamp(lp.X, -halfX, halfX), 0, math.clamp(lp.Z, -halfZ, halfZ))
	local world = info.cf:PointToWorldSpace(clamped)
	return Vector3.new(world.X, groundY(), world.Z)
end

-- Moves toward `goal`, ramping the current speed toward `speed` at Accel and turning the facing
-- toward the move at TurnRate; never into the Safe Zone. Returns true once within 1.5 studs or
-- when the boundary blocks any further progress.
local function step(g: Guardian, goal: Vector3, speed: number, dt: number, free: boolean): boolean
	goal = SafeZone.pushOut(goal)
	local delta = flat(goal - g.pos)
	local dist = delta.Magnitude
	if dist < 1.5 then
		return true
	end
	local diff = speed - g.speed
	g.speed += math.clamp(diff, -G.Accel * dt, G.Accel * dt)
	local dir = delta / dist
	local nextPos = g.pos + dir * math.min(dist, g.speed * dt)
	nextPos = if free then Vector3.new(nextPos.X, groundY(), nextPos.Z) else g.clamp(nextPos)
	nextPos = SafeZone.keepOut(g.pos, nextPos)
	local moved = flat(nextPos - g.pos).Magnitude
	g.pos = Vector3.new(nextPos.X, groundY(), nextPos.Z)
	local turned = g.facing:Lerp(dir, math.min(1, G.TurnRate * dt))
	g.facing = if turned.Magnitude > 0.01 then turned.Unit else dir
	place(g)
	return moved < 0.01
end

local function hasLineOfSight(g: Guardian, tpos: Vector3): boolean
	local ignore: { Instance } = { g.model }
	if rootFolder then
		table.insert(ignore, rootFolder)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	sightParams.FilterDescendantsInstances = ignore
	local from = g.pos + Vector3.new(0, G.SightHeight, 0)
	local to = Vector3.new(tpos.X, from.Y, tpos.Z)
	return workspace:Raycast(from, to - from, sightParams) == nil
end

local function endChase(g: Guardian, reason: string, knockback: Vector3?)
	local target = g.target
	g.target = nil
	g.waypoints = {}
	g.model:SetAttribute("Chasing", false)
	if g.state == "Chase" then
		g.state = "Return"
	end
	if target and reason == "safe" then
		escaped[target] = g.zone
	end
	if target and target.Parent then
		Net.fire("Chase", target, "end", g.def.Name, reason, knockback)
	end
end

local function startChase(g: Guardian, player: Player, now: number): boolean
	if g.state == "Chase" and g.target ~= player then
		return false
	end
	if SafeZone.isProtected(player) then
		return false
	end
	escaped[player] = nil
	g.state = "Chase"
	g.target = player
	g.chaseStartedAt = now
	g.waypoints = {}
	g.wpIdx = 1
	g.lastCompute = -math.huge
	g.lastGoal = Vector3.new(math.huge, 0, math.huge)
	g.losAt = -math.huge
	g.noCatchUntil = math.max(g.noCatchUntil, now + G.StartGraceSeconds)
	g.stuckFrom = g.pos
	g.stuckAt = now
	g.sleeping = false
	g.model:SetAttribute("Chasing", true)
	g.alert:Play()
	Net.fire("Chase", player, "start", g.def.Name)
	return true
end

local function catch(g: Guardian, player: Player, root: BasePart, now: number)
	if SafeZone.isProtected(player) then
		endChase(g, "safe")
		return
	end
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
	pathBusy = true
	local from = g.pos
	local ok = pcall(function()
		g.path:ComputeAsync(from, goal)
	end)
	g.computing = false
	pathBusy = false
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
	if SafeZone.contains(tpos) then
		endChase(g, "safe")
		return
	end
	if now - g.losAt >= G.SightSeconds then
		g.losAt = now
		g.los = hasLineOfSight(g, tpos)
	end
	local dist = flat(tpos - g.pos).Magnitude
	if now >= g.noCatchUntil and dist <= g.def.CatchRange and (g.los or dist <= g.def.CatchRange * 0.6) then
		catch(g, target, root, now)
		return
	end

	local session = Data.get(target)
	if session then
		local stat = session.data.speed
		local carrierWalk = Speed.walkSpeedFor(stat) * Config.Carry.SpeedFactor
		g.chaseSpeed = carrierWalk * (if stat > g.recommended then G.OutrunFactor else G.CatchFactor)
	end

	local lead = tpos + flat(root.AssemblyLinearVelocity) * g.def.Predict
	local goal = Vector3.new(lead.X, groundY(), lead.Z)
	local moveTo = goal
	if g.los then
		g.waypoints = {}
	else
		local wp = g.waypoints[g.wpIdx]
		while wp and flat(wp - g.pos).Magnitude <= G.WaypointReach do
			g.wpIdx += 1
			wp = g.waypoints[g.wpIdx]
		end
		local stale = wp == nil or flat(goal - g.lastGoal).Magnitude > G.RepathDistance
		if stale and not g.computing and not pathBusy and now - g.lastCompute >= g.def.RecomputeSeconds * G.RepathScale then
			g.lastCompute = now
			g.lastGoal = goal
			task.spawn(computePath, g, goal, target)
		end
		if wp then
			moveTo = wp
		end
	end
	step(g, moveTo, g.chaseSpeed, dt, true)

	-- A path that makes no headway is dropped and recomputed; the chase itself goes on.
	if (g.pos - g.stuckFrom).Magnitude >= G.StuckMinProgress then
		g.stuckFrom = g.pos
		g.stuckAt = now
	elseif now - g.stuckAt > G.BlockedSeconds then
		g.waypoints = {}
		g.lastCompute = -math.huge
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

-- A carrier who escaped to the Safe Zone and walks back into the guardian's own biome with
-- that biome's seed is a fair target again.
local function reacquire(now: number)
	for player, zone in escaped do
		local item = Carry.carried(player)
		if not player.Parent or not item or item.origin ~= zone then
			escaped[player] = nil
			continue
		end
		local root = Biomes.rootOf(player)
		if not root or SafeZone.contains(root.Position) then
			continue
		end
		for _, g in allGuardians() do
			if g.zone == zone and g.state ~= "Chase" and g.inRegion(root.Position) then
				startChase(g, player, now)
				break
			end
		end
	end
end

local function tick(dt: number)
	local now = os.clock()
	reacquire(now)
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

local function recommendedFor(def: GuardianDefs.Guardian): number
	local biome = BiomeData.ById[def.Biome]
	return def.RecommendedSpeed or (if biome then biome.RecommendedSpeed else 0)
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
	local recommended = recommendedFor(def)
	local baseSpeed = Speed.guardianSpeedFor(recommended)
	local root = model.PrimaryPart :: BasePart
	local g: Guardian = {
		def = def, zone = fields.zone, patrolPts = fields.patrolPts,
		inRegion = fields.inRegion, clamp = fields.clamp, model = model,
		path = PathfindingService:CreatePath({ AgentRadius = 2 * def.Scale, AgentHeight = 6 * def.Scale, AgentCanJump = false }),
		pos = pos, facing = Vector3.new(0, 0, -1), state = "Patrol", patrolIdx = 2,
		recommended = recommended, speed = 0, chaseSpeed = baseSpeed, patrolSpeed = baseSpeed * G.PatrolFactor,
		alignPos = root:FindFirstChildOfClass("AlignPosition") :: AlignPosition,
		alignOri = root:FindFirstChildOfClass("AlignOrientation") :: AlignOrientation,
		los = false, losAt = 0, lastGoal = pos,
		target = nil, chaseStartedAt = 0, noCatchUntil = 0, waypoints = {}, wpIdx = 1, lastCompute = 0,
		computing = false, stuckFrom = pos, stuckAt = 0, sleeping = true, alert = alert,
	}
	place(g)
	if root:IsDescendantOf(workspace) then
		pcall(root.SetNetworkOwner, root, nil)
	end
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
		table.insert(pts, SafeZone.pushOut(c + Vector3.new(math.cos(a) * inner, 0, math.sin(a) * inner)))
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
		escaped[player] = nil
		for _, g in allGuardians() do
			if g.target == player and g.state == "Chase" then
				endChase(g, reason)
			end
		end
	end)
	SafeZone.onEnter(function(player)
		for _, g in allGuardians() do
			if g.target == player and g.state == "Chase" then
				endChase(g, "safe")
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, g in allGuardians() do
			if g.target == player then
				endChase(g, "lost")
			end
		end
		escaped[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, g in allGuardians() do
			if g.state == "Chase" then
				chase(g, math.min(dt, 0.1), now)
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
