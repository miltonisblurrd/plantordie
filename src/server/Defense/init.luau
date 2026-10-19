--!strict
-- Night waves (P4, spec §9/§10). One loop runs every plot's lane simulation (Defense.Core) and
-- mirrors it onto anchored zombie models with PivotTo. Zombies only ever exist inside their
-- owner's plot field, so nothing here can touch another player's garden.
--
-- Fairness:
--   * A wave is built at nightfall for every online player who has a plot. Players who join
--     mid-night get their first wave the next night.
--   * Wave size scales with unlocked lanes (same density per lane) and stats scale with the
--     highest unlocked biome, so fewer-lane players are never overwhelmed.
--   * While the owner is inside a biome, spawning pauses. Zombies already on the lanes keep
--     coming. Unspawned zombies are dropped at dawn, so exploring at night is allowed but only a
--     defended wave pays a reward.
--   * Losing (house HP 0) clears the wave, forfeits its reward and takes a small capped penalty.
--     Plants are never lost: wilted plants recover at dawn or with a repair.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Config = require(ReplicatedStorage.Shared.Config)
local DropTables = require(ReplicatedStorage.Shared.DropTables)
local Format = require(ReplicatedStorage.Shared.Format)
local Houses = require(ReplicatedStorage.Shared.Houses)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Zombies = require(ReplicatedStorage.Shared.Zombies)
local Core = require(script.Core)
local Biomes = require(script.Parent.Biomes)
local Data = require(script.Parent.Data)
local DayNight = require(script.Parent.DayNight)
local Garden = require(script.Parent.Garden)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)
local Sync = require(script.Parent.Sync)
local PlotBuilder = require(script.Parent.World.Builders.Plot)
local ZombieModel = require(script.Parent.World.Builders.ZombieModel)
local Parts = require(script.Parent.World.Parts)

local D = Config.Defense
local P = Config.Plot
local FACE_HOUSE = CFrame.Angles(0, math.pi / 2, 0)

type Wave = {
	night: number,
	biome: number,
	queue: { string },
	total: number,
	nextSpawnAt: number,
	interval: number,
	spawned: number,
	killed: number,
	bounty: number,
	boss: boolean,
	lost: boolean,
}

type PlotState = {
	player: Player,
	idx: number,
	refs: PlotBuilder.PlotRefs,
	groundY: number,
	field: Core.Field,
	models: { [number]: Model },
	shown: { [number]: number }, -- last HP shown on each model
	trapParts: { [Core.Trap]: BasePart },
	folder: Folder,
	wave: Wave?,
	trapReadyAt: { [string]: number },
	repairReadyAt: number,
	dirty: boolean,
}

local Defense = {}

local survivedCallbacks: { (Player) -> () } = {}

-- Fires at dawn for each player whose house survived a wave that reached them.
function Defense.onNightSurvived(cb: (Player) -> ())
	table.insert(survivedCallbacks, cb)
end

local states: { [Player]: PlotState } = {}
local rng = Random.new()
local nextId = 0
local warnedNight = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function scaleOf(biome: number): number
	return 1 + D.HpPerBiome * (biome - 1)
end

local function incomeSeconds(player: Player, seconds: number, floor: number): number
	return math.max(floor, math.floor(Garden.incomeOf(player) * seconds))
end

local function houseX(tier: number): number
	local h = Houses.List[tier] or Houses.List[1]
	return P.HouseX + h.Size.X / 2
end

local function laneAndX(key: string): (number, number)
	local laneS, colS = string.match(key, "^(%d)_(%d)$")
	return tonumber(laneS) or 1, PlotBuilder.colX(tonumber(colS) or 1)
end

local function worldCFrame(st: PlotState, lane: number, x: number, y: number?): CFrame
	return st.refs.cframe * CFrame.new(x, st.groundY + (y or 0), PlotBuilder.laneZ(lane)) * FACE_HOUSE
end

local function syncPlant(player: Player, key: string)
	local st = states[player]
	local session = Data.get(player)
	if not st or not session then
		return
	end
	local rec = session.data.planted[key]
	if not rec then
		Core.removePlant(st.field, key)
		return
	end
	local stats = Combat.plantStats(rec.species, rec.size, rec.variant)
	local lane, x = laneAndX(key)
	local old = st.field.plants[key]
	Core.setPlant(st.field, key, lane, x, stats)
	if old and not old.wilted then
		local p = st.field.plants[key]
		p.hp = math.min(p.maxHp, old.hp)
	end
end

local function totalAlive(): number
	local n = 0
	for _, st in states do
		n += Core.alive(st.field)
	end
	return n
end

local function isAway(player: Player): boolean
	local root = Biomes.rootOf(player)
	return root ~= nil and Biomes.regionOf(root.Position) ~= nil
end

local function trapCost(player: Player, kind: string): number
	local t = D.Traps[kind]
	return incomeSeconds(player, t.CostIncomeSeconds, t.CostMin)
end

local function repairCost(player: Player): (number, number, number)
	local session = Data.get(player)
	if not session then
		return 0, 0, 0
	end
	local maxHp = (Houses.List[session.data.houseTier] or Houses.List[1]).MaxHp
	local missing = math.max(0, maxHp - Sync.houseHp(player))
	local wilted = #Garden.wiltedKeys(player)
	local cost = 0
	if missing > 0 then
		cost += math.ceil(incomeSeconds(player, D.RepairIncomeSeconds, D.RepairMin) * missing / maxHp)
	end
	return cost, missing, wilted
end

-- HUD block for the snapshot (Sync.setDefenseProvider).
local function hudFor(player: Player): { [string]: any }?
	local st = states[player]
	if not st then
		return nil
	end
	local w = st.wave
	local cost, missing, wilted = repairCost(player)
	return {
		active = w ~= nil and not w.lost,
		night = if w then w.night else 0,
		remaining = if w then #w.queue + Core.alive(st.field) else 0,
		total = if w then w.total else 0,
		lost = w ~= nil and w.lost,
		boss = w ~= nil and w.boss,
		repairCost = cost,
		repairNeeded = missing > 0 or wilted > 0,
		repairReadyAt = st.repairReadyAt,
		wilted = wilted,
		traps = {
			Spikes = { readyAt = st.trapReadyAt.Spikes or 0, cost = trapCost(player, "Spikes") },
			Freeze = { readyAt = st.trapReadyAt.Freeze or 0, cost = trapCost(player, "Freeze") },
		},
	}
end

local function destroyModel(st: PlotState, id: number)
	local m = st.models[id]
	if m then
		m:Destroy()
		st.models[id] = nil
		st.shown[id] = nil
	end
end

local function spawnOne(st: PlotState, kind: string, t: number)
	local w = st.wave :: Wave
	local session = Data.get(st.player)
	if not session then
		return
	end
	local lane = rng:NextInteger(1, math.clamp(session.data.lanesUnlocked, 1, P.Lanes))
	local x = P.ZombieSpawnX + rng:NextNumber() * D.LaneSpawnJitter
	nextId += 1
	local stats = Zombies.stats(kind, w.biome, w.night)
	local strength = Upgrades.portalOf(session.data.portalTier).Strength
	stats.hp = math.floor(stats.hp * strength)
	stats.armor = math.floor(stats.armor * strength)
	stats.damage *= strength
	local z = Core.addZombie(st.field, nextId, kind, lane, x, stats, t)
	local m = ZombieModel.build(Zombies.ById[kind], worldCFrame(st, lane, x), st.folder)
	m:SetAttribute("ZombieId", z.id)
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Owner", st.player.UserId)
	m:SetAttribute("MaxHp", z.maxHp + z.maxArmor)
	m:SetAttribute("Hp", z.hp + z.armor)
	st.models[z.id] = m
	st.shown[z.id] = z.hp + z.armor
	w.spawned += 1
	st.dirty = true
end

local function clearZombies(st: PlotState, reason: string)
	for _, z in st.field.zombies do
		if not z.dead then
			z.dead = true
			z.reason = reason
		end
	end
	for _, z in Core.sweep(st.field) do
		destroyModel(st, z.id)
	end
	st.field.traps = {}
	for _, part in st.trapParts do
		part:Destroy()
	end
	st.trapParts = {}
end

local function loseWave(st: PlotState)
	local w = st.wave
	if not w or w.lost then
		return
	end
	w.lost = true
	w.queue = {}
	clearZombies(st, "lost")
	local session = Data.get(st.player)
	local penalty = 0
	if session then
		local cap = Garden.incomeOf(st.player) * D.LossPenaltyIncomeSeconds
		penalty = math.floor(math.min(session.data.money * D.LossPenaltyFraction, cap))
		if penalty > 0 then
			Data.update(st.player, function(p)
				p.money = math.max(0, p.money - penalty)
			end)
		end
	end
	Net.notify(
		st.player,
		`Your house fell! Wave lost{if penalty > 0 then `, repairs cost {Format.money(penalty)}` else ""}. Your plants are safe.`,
		"error"
	)
	st.dirty = true
end

type Fx = { k: string, a: Vector3, b: Vector3?, r: number?, c: Color3? }

local ROLE_COLOR: { [string]: Color3 } = {
	Projectile = Color3.fromRGB(120, 230, 90),
	Rapid = Color3.fromRGB(255, 230, 90),
	Slow = Color3.fromRGB(130, 210, 255),
	Burn = Color3.fromRGB(255, 120, 40),
	Wall = Color3.fromRGB(200, 170, 120),
}

local function applyEvents(st: PlotState, events: { Core.Event }, fx: { Fx })
	local w = st.wave
	local kills = 0
	for _, e in events do
		local z, p = e.zombie, e.plant
		if e.kind == "shot" and z and p and p.stats then
			table.insert(fx, { k = "bolt", a = worldCFrame(st, p.lane, p.x, 2.5).Position,
				b = worldCFrame(st, z.lane, z.x, 2.5).Position, c = ROLE_COLOR[p.stats.role] })
		elseif e.kind == "splash" and p then
			table.insert(fx, { k = "ring", a = worldCFrame(st, p.lane, p.x, 0.3).Position, r = e.amount,
				c = Color3.fromRGB(255, 140, 60) })
		elseif e.kind == "spit" and z and p then
			table.insert(fx, { k = "bolt", a = worldCFrame(st, z.lane, z.x, 3).Position,
				b = worldCFrame(st, p.lane, p.x, 1.5).Position, c = Color3.fromRGB(160, 255, 60) })
		elseif e.kind == "freeze" and e.lane and e.x then
			table.insert(fx, { k = "ring", a = worldCFrame(st, e.lane, e.x, 0.3).Position, r = e.amount,
				c = Color3.fromRGB(150, 230, 255) })
		elseif e.kind == "wilt" and p then
			Garden.stun(st.player, p.key)
			st.dirty = true
		elseif e.kind == "kill" and z then
			kills += 1
			if w then
				w.killed += 1
				w.bounty += z.bounty
			end
			table.insert(fx, { k = "pop", a = worldCFrame(st, z.lane, z.x, 2.5).Position })
		elseif e.kind == "house" and z then
			Sync.setHouseHp(st.player, Sync.houseHp(st.player) - (e.amount or 0))
			table.insert(fx, { k = "ring", a = worldCFrame(st, z.lane, z.x, 0.3).Position, r = 6,
				c = Color3.fromRGB(255, 60, 60) })
			if Sync.houseHp(st.player) <= 0 then
				loseWave(st)
			end
		end
	end
	if kills > 0 then
		Data.update(st.player, function(prof)
			prof.stats.zombiesKilled += kills
		end)
		st.dirty = true
	end
end

local function render(st: PlotState)
	for id, z in st.field.zombies do
		local m = st.models[id]
		if m and not z.dead then
			local lean = if z.attacking then 0 else math.sin(os.clock() * 7 + z.id) * 0.18
			m:PivotTo(worldCFrame(st, z.lane, z.x) * CFrame.Angles(lean, 0, lean * 0.4))
			local hp = math.ceil(z.hp + z.armor)
			if st.shown[id] ~= hp then
				st.shown[id] = hp
				m:SetAttribute("Hp", hp)
			end
		end
	end
	for _, z in Core.sweep(st.field) do
		destroyModel(st, z.id)
	end
	local live: { [Core.Trap]: boolean } = {}
	for _, t in st.field.traps do
		live[t] = true
	end
	for t, part in st.trapParts do
		if not live[t] then
			part:Destroy()
			st.trapParts[t] = nil
		end
	end
end

local function tick(dt: number)
	local t = now()
	local isNight = DayNight.phase() == "Night"
	local serverAlive = totalAlive()
	local fx: { Fx } = {}
	for player, st in states do
		local w = st.wave
		if isNight and w and not w.lost and #w.queue > 0 and t >= w.nextSpawnAt then
			w.nextSpawnAt = t + w.interval
			if not isAway(player) and Core.alive(st.field) < D.MaxPerPlot and serverAlive < D.MaxPerServer then
				spawnOne(st, table.remove(w.queue, 1) :: string, t)
				serverAlive += 1
			end
		end
		if next(st.field.zombies) ~= nil or #st.field.traps > 0 then
			local events: { Core.Event } = {}
			Core.step(st.field, dt, t, events)
			applyEvents(st, events, fx)
			render(st)
		end
		if st.dirty then
			st.dirty = false
			Sync.push(player)
		end
	end
	if #fx > 0 then
		Net.fireAll("CombatFx", fx)
	end
end

local function startWave(player: Player, night: number)
	local st = states[player]
	local session = Data.get(player)
	if not st or not session then
		return
	end
	local biome = Biomes.highestUnlocked(session.data)
	local queue = Zombies.compose(night, biome, session.data.lanesUnlocked, rng)
	st.field.houseX = houseX(session.data.houseTier)
	st.field.trapPower = scaleOf(biome)
	local boss = night % Zombies.BossEveryNights == 0
	st.wave = {
		night = night, biome = biome, queue = queue, total = #queue,
		nextSpawnAt = now() + 3, interval = Config.DayNight.NightSeconds * D.SpawnWindow / math.max(1, #queue),
		spawned = 0, killed = 0, bounty = 0, boss = boss, lost = false,
	}
	Net.notify(
		player,
		`Night {night}: your portal is opening. {#queue} monsters are walking out!{if boss then " A ROT KING leads them!" else ""}`,
		"warn"
	)
	st.dirty = true
end

-- Dawn: grant the wave reward once if the house held, then reset the field.
local function endWave(player: Player)
	local st = states[player]
	if not st then
		return
	end
	local w = st.wave
	st.wave = nil
	clearZombies(st, "dawn")
	local events: { Core.Event } = {}
	Core.dawn(st.field, events)
	Sync.resetHouseHp(player)
	local session = Data.get(player)
	if not w or not session then
		return
	end
	if w.lost then
		return
	end
	if w.spawned == 0 then
		Net.notify(player, "You were away all night, so no wave reached you and no reward was earned.")
		return
	end
	local money = w.bounty * incomeSeconds(player, D.BountyIncomeSeconds, D.BountyMin)
		+ incomeSeconds(player, D.SurviveBonusIncomeSeconds, D.SurviveBonusMin)
	local biome = BiomeData.List[w.biome] or BiomeData.List[1]
	local drop = DropTables.roll(biome.Id, 0, rng:NextNumber())
	Data.update(player, function(p)
		p.money += money
		p.stats.moneyEarned += money
		p.stats.nightsSurvived += 1
		if drop then
			p.seeds[drop.Plant] = (p.seeds[drop.Plant] or 0) + 1
		end
	end)
	for _, cb in survivedCallbacks do
		task.spawn(cb, player)
	end
	local seedName = if drop and Plants.ById[drop.Plant] then Plants.ById[drop.Plant].Name else nil
	Net.notify(
		player,
		`Night {w.night} survived! +{Format.money(money)}{if seedName then ` and a bonus {seedName} seed` else ""}.`
	)
end

local function onPhase(phase: string, night: number)
	for player in states do
		if phase == "Night" then
			startWave(player, night)
		else
			endWave(player)
		end
	end
end

local function attach(player: Player, idx: number)
	local refs = Plots.refs(idx)
	local session = Data.get(player)
	if not refs or not session then
		return
	end
	local tile = refs.tiles[PlotBuilder.tileKey(1, 1)]
	local top = tile.CFrame * CFrame.new(0, tile.Size.Y / 2, 0)
	local folder = Instance.new("Folder")
	folder.Name = "Zombies"
	folder.Parent = refs.model
	local st: PlotState = {
		player = player, idx = idx, refs = refs,
		groundY = refs.cframe:PointToObjectSpace(top.Position).Y,
		field = Core.newField(houseX(session.data.houseTier), scaleOf(Biomes.highestUnlocked(session.data))),
		models = {}, shown = {}, trapParts = {}, folder = folder, wave = nil,
		trapReadyAt = {}, repairReadyAt = 0, dirty = true,
	}
	states[player] = st
	for key in session.data.planted do
		syncPlant(player, key)
	end
end

local function detach(player: Player)
	local st = states[player]
	if not st then
		return
	end
	clearZombies(st, "lost")
	st.folder:Destroy()
	states[player] = nil
end

local function repair(player: Player)
	local st = states[player]
	local session = Data.get(player)
	if not st or not session then
		return
	end
	local t = now()
	if t < st.repairReadyAt then
		Net.notify(player, `Repair is cooling down ({math.ceil(st.repairReadyAt - t)}s).`, "error")
		return
	end
	local cost, missing, wilted = repairCost(player)
	if missing <= 0 and wilted <= 0 then
		Net.notify(player, "Your house and plants are in full health.")
		return
	end
	if session.data.money < cost then
		Net.notify(player, `Repair costs {Format.money(cost)}.`, "error")
		return
	end
	st.repairReadyAt = t + D.RepairCooldown
	Data.update(player, function(p)
		p.money -= cost
	end)
	Sync.resetHouseHp(player)
	Net.notify(player, `House repaired for {Format.money(cost)}. Stunned plants wake up on their own, or for 11 Robux.`)
	st.dirty = true
end

local function useTrap(player: Player, kind: string)
	local st = states[player]
	local session = Data.get(player)
	local spec = D.Traps[kind]
	if not st or not session or not spec then
		return
	end
	local t = now()
	if DayNight.phase() ~= "Night" or not st.wave or st.wave.lost then
		Net.notify(player, "Traps only work during a night wave.", "error")
		return
	end
	if t < (st.trapReadyAt[kind] or 0) then
		Net.notify(player, `{kind} is cooling down ({math.ceil((st.trapReadyAt[kind] or 0) - t)}s).`, "error")
		return
	end
	local lead: Core.Zombie? = nil
	for _, z in st.field.zombies do
		if not z.dead and (not lead or z.x < lead.x) then
			lead = z
		end
	end
	if not lead then
		Net.notify(player, "No zombies on your lanes yet.", "error")
		return
	end
	local cost = trapCost(player, kind)
	if session.data.money < cost then
		Net.notify(player, `{kind} costs {Format.money(cost)}.`, "error")
		return
	end
	st.trapReadyAt[kind] = t + spec.Cooldown
	Data.update(player, function(p)
		p.money -= cost
	end)
	local x = math.max(st.field.houseX + 3, lead.x - (if kind == "Spikes" then 4 else 3))
	local trap: Core.Trap = {
		kind = kind, lane = lead.lane, x = x, triggered = false,
		endsAt = t + (if kind == "Spikes" then spec.Seconds else spec.ArmSeconds),
	}
	table.insert(st.field.traps, trap)
	local part = Parts.make({
		Name = kind, Parent = st.folder, CanCollide = false,
		Color = if kind == "Spikes" then Color3.fromRGB(90, 90, 100) else Color3.fromRGB(150, 230, 255),
		Material = if kind == "Spikes" then Enum.Material.Metal else Enum.Material.Neon,
		Size = if kind == "Spikes" then Vector3.new(spec.HalfWidth * 2, 0.5, P.TileSize * 0.8) else Vector3.new(2.4, 0.5, 2.4),
		CFrame = st.refs.cframe * CFrame.new(x, st.groundY + 0.25, PlotBuilder.laneZ(lead.lane)),
	})
	st.trapParts[trap] = part
	Net.notify(player, `{if kind == "Spikes" then "Spike strip" else "Freeze mine"} placed in lane {lead.lane}.`)
	st.dirty = true
end

local function hitZombie(player: Player, id: number)
	local st = states[player]
	if not st or not st.wave or st.wave.lost then
		return
	end
	local z = st.field.zombies[id]
	local m = st.models[id]
	local root = Biomes.rootOf(player)
	if not z or z.dead or not m or not root then
		return
	end
	if (m:GetPivot().Position - root.Position).Magnitude > D.AssistRange then
		return
	end
	local events: { Core.Event } = {}
	Core.damage(z, math.max(D.AssistMinDamage, (z.maxHp + z.maxArmor) * D.AssistDamageFraction), "player", events)
	local fx: { Fx } = {}
	applyEvents(st, events, fx)
	render(st)
	if #fx > 0 then
		Net.fireAll("CombatFx", fx)
	end
end

function Defense.start()
	Sync.setDefenseProvider(hudFor)
	Plots.onAssigned(attach)
	Plots.onReleased(function(player)
		detach(player)
	end)
	Players.PlayerRemoving:Connect(detach)
	Garden.onPlantChanged(syncPlant)
	DayNight.onPhaseChanged(onPhase)
	Net.on("Repair", {}, repair)
	Net.on("UseTrap", { "string" }, useTrap)
	Net.on("HitZombie", { "number" }, hitZombie)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(D.TickSeconds)
			local c = os.clock()
			local dt = math.min(c - last, 0.5)
			last = c
			if DayNight.phase() == "Day" then
				local nextNight = DayNight.nightNumber() + 1
				if warnedNight < nextNight and DayNight.endsAt() - now() <= D.WarningSeconds then
					warnedNight = nextNight
					for player in states do
						Net.notify(player, `Zombies attack in {D.WarningSeconds} seconds! Get home to defend your garden.`, "warn")
					end
				end
			end
			tick(dt)
		end
	end)
end

return Defense
