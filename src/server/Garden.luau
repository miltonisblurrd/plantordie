--!strict
-- Grid, growth, and income. Saved state is profile.planted (tile key -> record); models are a
-- pure function of that state, so rejoining just rebuilds them. Growth is timestamp based, so
-- plants keep growing while the player is offline.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Houses = require(ReplicatedStorage.Shared.Houses)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)
local PlotBuilder = require(script.Parent.World.Builders.Plot)
local PlantModel = require(script.Parent.World.Builders.PlantModel)

local G = Config.Garden

local Garden = {}

-- `wilted` is night-only state from Defense: a wilted plant keeps its record but earns nothing
-- until dawn or a repair. It is not saved, so a rejoin also recovers it.
type View = { models: { [string]: Model }, stages: { [string]: number }, wilted: { [string]: boolean? }, income: number }
local views: { [Player]: View } = {}
local rng = Random.new()
local changedCallbacks: { (Player, string) -> () } = {}
local WILT_COLOR = Color3.fromRGB(96, 74, 52)

-- Fires after a tile's plant appears, changes stage, or is removed.
function Garden.onPlantChanged(cb: (Player, string) -> ())
	table.insert(changedCallbacks, cb)
end

local function tintWilted(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = d.Color:Lerp(WILT_COLOR, 0.75)
			d.Material = Enum.Material.SmoothPlastic
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Sparkles") then
			d:Destroy()
		end
	end
end

function Garden.incomeOf(player: Player): number
	local v = views[player]
	return if v then v.income else 0
end

local function growthMult(profile: Data.Profile): number
	return Economy.growthMultiplier(profile, os.time())
end

function Garden.isGrown(player: Player, key: string): boolean
	local session = Data.get(player)
	if not session then
		return false
	end
	local rec = session.data.planted[key]
	return rec ~= nil and Economy.isGrown(rec, os.time(), growthMult(session.data))
end

local function setTileOccupied(refs: PlotBuilder.PlotRefs, key: string, occupied: boolean)
	local tile = refs.tiles[key]
	if tile then
		tile:SetAttribute("Occupied", occupied)
	end
end

local function render(player: Player, key: string)
	local v = views[player]
	local idx = Plots.plotOf(player)
	local session = Data.get(player)
	if not v or not idx or not session then
		return
	end
	local refs = Plots.refs(idx) :: PlotBuilder.PlotRefs
	local old = v.models[key]
	if old then
		old:Destroy()
		v.models[key] = nil
		v.stages[key] = nil
	end
	local rec = session.data.planted[key]
	if not rec then
		v.wilted[key] = nil
		setTileOccupied(refs, key, false)
		for _, cb in changedCallbacks do
			task.spawn(cb, player, key)
		end
		return
	end
	local tile = refs.tiles[key]
	if not tile or not Plants.ById[rec.species] then
		return
	end
	local mult = growthMult(session.data)
	local _, stage = Economy.growth(rec, os.time(), mult)
	local base = tile.CFrame * CFrame.new(0, tile.Size.Y / 2, 0)
	local m = PlantModel.build(rec, stage, base, refs.plants)
	m.Name = "Plant_" .. key
	m:SetAttribute("PlotIndex", idx)
	m:SetAttribute("TileKey", key)
	m:SetAttribute("Species", rec.species)
	m:SetAttribute("Rarity", rec.rarity)
	m:SetAttribute("Size", rec.size)
	m:SetAttribute("Variant", rec.variant)
	m:SetAttribute("PlantedAt", rec.plantedAt)
	m:SetAttribute("Matured", rec.matured == true)
	m:SetAttribute("GrowSeconds", Economy.effectiveGrowSeconds(rec, mult))
	m:SetAttribute("Income", Economy.incomeOf(rec))
	m:SetAttribute("Stage", stage)
	v.models[key] = m
	v.stages[key] = stage
	if v.wilted[key] then
		m:SetAttribute("Wilted", true)
		tintWilted(m)
	end
	setTileOccupied(refs, key, true)
	for _, cb in changedCallbacks do
		task.spawn(cb, player, key)
	end
end

function Garden.setWilted(player: Player, key: string, on: boolean)
	local v = views[player]
	if not v or (v.wilted[key] == true) == on then
		return
	end
	v.wilted[key] = if on then true else nil
	if on then
		local m = v.models[key]
		if m then
			m:SetAttribute("Wilted", true)
			tintWilted(m)
		end
	else
		render(player, key)
	end
end

function Garden.wiltedKeys(player: Player): { string }
	local v = views[player]
	local out = {}
	if v then
		for key in v.wilted do
			table.insert(out, key)
		end
	end
	return out
end

local function clearViews(player: Player, idx: number)
	local v = views[player]
	local refs = Plots.refs(idx)
	if v then
		for _, m in v.models do
			m:Destroy()
		end
	end
	if refs then
		refs.plants:ClearAllChildren()
		for key in refs.tiles do
			setTileOccupied(refs, key, false)
		end
	end
	views[player] = nil
end

local function restore(player: Player)
	local session = Data.get(player)
	if not session then
		return
	end
	views[player] = { models = {}, stages = {}, wilted = {}, income = 0 }
	for key in session.data.planted do
		render(player, key)
	end
end

local function onAssigned(player: Player)
	local session = Data.get(player)
	if not session then
		return
	end
	local d = session.data
	local now = os.time()

	local earned, seconds = Economy.offlineEarnings(d.planted, d.lastSeen, now, growthMult(d))
	local grantStarter = not d.starterGranted
	Data.update(player, function(p)
		if earned > 0 then
			p.money += earned
			p.stats.moneyEarned += earned
		end
		if grantStarter then
			for species, n in G.StarterSeeds do
				p.seeds[species] = (p.seeds[species] or 0) + n
			end
			p.starterGranted = true
		end
	end)

	restore(player)

	if grantStarter then
		Net.notify(player, "Welcome! You got a starter seed pack. Open Seeds and tap a soil tile to plant.")
	end
	if earned > 0 then
		local hours = seconds / 3600
		Net.notify(
			player,
			`Welcome back! Your garden earned {Format.money(earned)} while you were away ({string.format("%.1f", hours)}h).`
		)
	end
end

-- Validates a tile action. Returns session, refs, lane, or nil + player-facing reason.
local function checkTile(player: Player, key: string): (Data.Session?, PlotBuilder.PlotRefs?, number?, string?)
	local session = Data.get(player)
	local idx = Plots.plotOf(player)
	if not session or not idx then
		return nil, nil, nil, "You don't have a plot yet."
	end
	local laneS, colS = string.match(key, "^(%d)_(%d)$")
	local lane, col = tonumber(laneS), tonumber(colS)
	if not lane or not col or lane < 1 or lane > Config.Plot.Lanes or col < 1 or col > Config.Plot.Columns then
		return nil, nil, nil, "That isn't a garden tile."
	end
	local refs = Plots.refs(idx) :: PlotBuilder.PlotRefs
	local tile = refs.tiles[key]
	if not tile or not Plots.isOwner(player, tile) then
		return nil, nil, nil, "You can only plant on your own plot."
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - tile.Position).Magnitude > G.MaxPlantDistance then
		return nil, nil, nil, "Get closer to your garden to do that."
	end
	return session, refs, lane, nil
end

local function countPlanted(profile: Data.Profile): number
	local n = 0
	for _ in profile.planted do
		n += 1
	end
	return n
end

-- Checks shared by planting a seed and placing an inventory plant.
local function checkPlantable(player: Player, key: string): (Data.Session?, string?)
	local session, _, lane, reason = checkTile(player, key)
	if not session or not lane then
		return nil, reason
	end
	local d = session.data
	if lane > d.lanesUnlocked then
		return nil, `Lane {lane} is locked. Unlock it at the lane sign.`
	end
	if d.planted[key] then
		return nil, "That tile already has a plant."
	end
	local house = Houses.List[d.houseTier] or Houses.List[1]
	if countPlanted(d) >= house.Slots then
		return nil, `Your {house.Name} holds {house.Slots} plants. Upgrade your house for more slots.`
	end
	return session, nil
end

local function waterOk(profile: Data.Profile, speciesId: string): boolean
	local def = Plants.ById[speciesId]
	if not def or not def.WaterDependent then
		return true
	end
	local w = profile.water
	return w.channel or w.sprinkler or w.pond
end

-- All checks and the state write run without yielding, so spammed remotes can't double-spend.
local function plantSeed(player: Player, key: string, species: string)
	local session, reason = checkPlantable(player, key)
	if not session then
		Net.notify(player, reason or "Can't plant there.", "error")
		return
	end
	local d = session.data
	local def = Plants.ById[species]
	if not def or (d.seeds[species] or 0) < 1 then
		Net.notify(player, "You don't have that seed.", "error")
		return
	end
	if not waterOk(d, species) then
		Net.notify(player, `{def.Name} needs a water upgrade first.`, "error")
		return
	end
	local size = Economy.rollSize(species, rng)
	Data.update(player, function(p)
		p.seeds[species] -= 1
		if p.seeds[species] <= 0 then
			p.seeds[species] = nil
		end
		p.planted[key] = {
			species = species,
			rarity = def.Rarity,
			size = size,
			variant = "Normal",
			plantedAt = os.time(),
		}
		p.collection[species .. "|Normal"] = true
		p.stats.plantsPlanted += 1
	end)
	render(player, key)
	Net.notify(player, `Planted {def.Name} ({size}).`)
end

local function placePlant(player: Player, key: string, itemId: string)
	local session, reason = checkPlantable(player, key)
	if not session then
		Net.notify(player, reason or "Can't place there.", "error")
		return
	end
	local item = session.data.plants[itemId]
	if not item or not Plants.ById[item.species] then
		Net.notify(player, "You don't have that plant.", "error")
		return
	end
	Data.update(player, function(p)
		p.plants[itemId] = nil
		p.planted[key] = {
			species = item.species,
			rarity = item.rarity,
			size = item.size,
			variant = item.variant,
			plantedAt = os.time(),
			matured = true,
		}
	end)
	render(player, key)
	Net.notify(player, `Placed {Plants.ById[item.species].Name}.`)
end

local function removePlant(player: Player, key: string)
	local session, _, _, reason = checkTile(player, key)
	if not session then
		Net.notify(player, reason or "Can't do that.", "error")
		return
	end
	local rec = session.data.planted[key]
	if not rec then
		return
	end
	local def = Plants.ById[rec.species]
	local name = if def then def.Name else rec.species
	local grown = Economy.isGrown(rec, os.time(), growthMult(session.data))
	Data.update(player, function(p)
		p.planted[key] = nil
		if grown then
			local id = tostring(p.nextItemId)
			p.nextItemId += 1
			p.plants[id] = {
				id = id,
				species = rec.species,
				rarity = rec.rarity,
				size = rec.size,
				variant = rec.variant,
			}
		elseif G.UnripeSeedRefund > 0 then
			p.seeds[rec.species] = (p.seeds[rec.species] or 0) + G.UnripeSeedRefund
		end
	end)
	render(player, key)
	if grown then
		Net.notify(player, `{name} moved to your plant inventory.`)
	elseif G.UnripeSeedRefund > 0 then
		Net.notify(player, `Dug up {name}. Seed refunded.`)
	else
		Net.notify(player, `Dug up {name} before it grew. Nothing was returned.`, "warn")
	end
end

local function tick()
	local now = os.time()
	for player, v in views do
		local session = Data.get(player)
		if session then
			local d = session.data
			local mult = growthMult(d)
			local total = 0
			for key, rec in d.planted do
				local _, stage = Economy.growth(rec, now, mult)
				if stage ~= v.stages[key] then
					render(player, key)
				else
					local m = v.models[key]
					local secs = Economy.effectiveGrowSeconds(rec, mult)
					if m and m:GetAttribute("GrowSeconds") ~= secs then
						m:SetAttribute("GrowSeconds", secs)
					end
				end
				if stage == 4 and not v.wilted[key] then
					total += Economy.incomeOf(rec)
				end
			end
			v.income = total
			if total > 0 then
				local gained = total * G.TickSeconds
				Data.update(player, function(p)
					p.money += gained
					p.stats.moneyEarned += gained
				end)
			end
		end
	end
end

function Garden.start()
	Plots.onAssigned(onAssigned)
	Plots.onReleased(clearViews)
	Players.PlayerRemoving:Connect(function(player)
		views[player] = nil
	end)

	Net.on("PlantSeed", { "string", "string" }, plantSeed)
	Net.on("PlacePlant", { "string", "string" }, placePlant)
	Net.on("RemovePlant", { "string" }, removePlant)

	task.spawn(function()
		while true do
			task.wait(G.TickSeconds)
			tick()
		end
	end)
end

return Garden
