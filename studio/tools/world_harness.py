#!/usr/bin/env python3
"""Runs the real world builders and shared data modules under the plain `luau` CLI with a
minimal Roblox API stub, then prints part counts, dig-table odds and the pacing table.

The stub keeps positions but ignores rotations, so it is only good for counting things and
for pure-data checks. It is not a physics or gameplay test.

Usage: python3 studio/tools/world_harness.py
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAPS = {"src/shared": "ReplicatedStorage/Shared", "src/server": "ServerScriptService/Server"}

RUNTIME = r'''
local SOURCES = ...
local MODULE_CACHE = {}

-- Minimal Vector3 / CFrame (translation only) -----------------------------------------
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return Vector3.new(v.X / m, v.Y / m, v.Z / m) end
	return nil
end
Vector3 = {}
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
Vector3.one = Vector3.new(1, 1, 1)
Vector3.zero = Vector3.new(0, 0, 0)
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
V3.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
Vector2 = { new = function(x, y) return Vector3.new(x, 0, y) end }

local CF = {}
CFrame = {}
local function cf(p) return setmetatable({ Position = p, Rotation = nil }, CF) end
CF.__index = function(c, k)
	if k == "Rotation" then return cf(Vector3.zero) end
	if k == "X" then return c.Position.X end
	if k == "Y" then return c.Position.Y end
	if k == "Z" then return c.Position.Z end
	if k == "PointToObjectSpace" then return function(self, v) return v - self.Position end end
	if k == "PointToWorldSpace" then return function(self, v) return v + self.Position end end
	if k == "LookVector" then return Vector3.new(0, 0, -1) end
	return nil
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then return a.Position + b end
	return cf(a.Position + b.Position)
end
CF.__add = function(a, b) return cf(a.Position + b) end
CF.__sub = function(a, b) return cf(a.Position - b) end
function CFrame.new(x, y, z)
	if type(x) == "table" then return cf(x) end
	return cf(Vector3.new(x or 0, y or 0, z or 0))
end
function CFrame.Angles() return cf(Vector3.zero) end
function CFrame.fromEulerAnglesXYZ() return cf(Vector3.zero) end
function CFrame.lookAt(p) return cf(p) end
CFrame.identity = cf(Vector3.zero)

Color3 = {}
local C3 = { __index = { Lerp = function(a, b, t) return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end } }
function Color3.new(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end
function Color3.fromRGB(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
function Color3.fromHex(h)
	h = h:gsub("#", "")
	return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
end
function Color3.fromHSV(h, s, v) return Color3.new(v, v, v) end

-- Generic "anything" value for enums, UDim2, NumberSequence, etc.
local Any
Any = setmetatable({}, {
	__index = function() return Any end,
	__call = function() return Any end,
	__mul = function() return Any end, __add = function() return Any end,
	__sub = function() return Any end, __div = function() return Any end,
})
Enum = Any
UDim2 = Any
UDim = Any
NumberSequence = Any
NumberRange = Any
ColorSequence = Any
TweenInfo = Any

-- Random: deterministic LCG with Roblox's API shape.
Random = {}
function Random.new(seed)
	local s = (seed or 1) % 2147483647
	if s <= 0 then s = s + 2147483646 end
	local r = {}
	function r:NextNumber(a, b)
		s = (s * 16807) % 2147483647
		local f = s / 2147483647
		if a == nil then return f end
		return a + (b - a) * f
	end
	function r:NextInteger(a, b) return math.floor(self:NextNumber(a, b + 1)) end
	return r
end

-- Instances --------------------------------------------------------------------------
local counts = { BasePart = 0, Instance = 0 }
local INST = {}
local function isPart(cls) return cls == "Part" or cls == "WedgePart" or cls == "SpawnLocation" end
local function newInstance(cls, name, source)
	local o = { ClassName = cls, Name = name or cls, _children = {}, _attrs = {}, _source = source }
	counts.Instance += 1
	if isPart(cls) then counts.BasePart += 1 end
	return setmetatable(o, INST)
end
local methods = {}
function methods:SetAttribute(k, v) self._attrs[k] = v end
function methods:GetAttribute(k) return self._attrs[k] end
function methods:FindFirstChild(n)
	for _, c in self._children do if c.Name == n then return c end end
	return nil
end
function methods:WaitForChild(n) return self:FindFirstChild(n) end
function methods:FindFirstChildOfClass(cls)
	for _, c in self._children do if c.ClassName == cls then return c end end
	return nil
end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
	local out = {}
	local function walk(n) for _, c in n._children do table.insert(out, c); walk(c) end end
	walk(self)
	return out
end
function methods:IsA(cls)
	if cls == "BasePart" then return isPart(self.ClassName) end
	if cls == "ModuleScript" then return self._source ~= nil end
	return self.ClassName == cls
end
function methods:PivotTo() end
function methods:Destroy() end
function methods:Clone() return self end
function methods:CreatePath() return {} end
INST.__index = function(o, k)
	if methods[k] then return methods[k] end
	local child = methods.FindFirstChild(o, k)
	if child then return child end
	if k == "Changed" or k == "Touched" or k == "Activated" or k:match("Changed$") or k:match("Triggered$")
		or k:match("Added$") or k:match("Removing$") or k == "Heartbeat" or k == "Stepped" or k == "OnServerEvent" then
		return { Connect = function() return { Disconnect = function() end } end }
	end
	return nil
end
INST.__newindex = function(o, k, v)
	if k == "Parent" then
		local old = rawget(o, "_parent")
		if old then
			for i, c in old._children do if c == o then table.remove(old._children, i) break end end
		end
		rawset(o, "_parent", v)
		if v then table.insert(v._children, o) end
		return
	end
	rawset(o, k, v)
end
local parentGetter = INST.__index
INST.__index = function(o, k)
	if k == "Parent" then return rawget(o, "_parent") end
	return parentGetter(o, k)
end

Instance = { new = function(cls) return newInstance(cls) end }

-- Fake DataModel built from the bundled sources.
game = newInstance("DataModel", "game")
local function ensure(path)
	local node = game
	for part in path:gmatch("[^/]+") do
		local child = methods.FindFirstChild(node, part)
		if not child then
			child = newInstance("Folder", part)
			child.Parent = node
		end
		node = child
	end
	return node
end
for path, src in SOURCES do
	local node = ensure(path)
	rawset(node, "_source", src)
	rawset(node, "ClassName", "ModuleScript")
end
counts.Instance = 0
workspace = ensure("Workspace")
function methods:GetService(name) return ensure(name) end

require = function(node)
	if MODULE_CACHE[node] ~= nil then return MODULE_CACHE[node] end
	local src = rawget(node, "_source")
	assert(src, "no source for " .. tostring(node.Name))
	local fn = assert(loadstring(src, "=" .. node.Name))
	local env = setmetatable({ script = node }, { __index = getfenv(1) })
	setfenv(fn, env)
	local result = fn()
	MODULE_CACHE[node] = result
	return result
end

task = { spawn = function() end, delay = function() end, wait = function() return 0 end, defer = function() end }

-- Run ---------------------------------------------------------------------------------
local Server = ensure("ServerScriptService/Server")
local Shared = ensure("ReplicatedStorage/Shared")
local Parts = require(Server.World.Parts)
local Layout = require(Server.World.Layout)
local Kit = require(Server.World.BiomeKit)
local Gate = require(Server.World.Builders.Gate)
local Hub = require(Server.World.Builders.Hub)
local PlotBuilder = require(Server.World.Builders.Plot)
local GuardianRig = require(Server.World.Builders.GuardianRig)
local Biomes = require(Shared.Biomes)
local Guardians = require(Shared.Guardians)
local Config = require(Shared.Config)
local Plants = require(Shared.Plants)
local DropTables = require(Shared.DropTables)
local Upgrades = require(Shared.Upgrades)
local Houses = require(Shared.Houses)

local world = newInstance("Folder", "World")
local function delta(fn)
	local before = Parts.count()
	fn()
	return Parts.count() - before
end

print("== Part counts (Parts.make calls; SpawnLocation not included) ==")
print(("Hub: %d"):format(delta(function() Hub.build(world) end)))
local plots = delta(function()
	for i = 1, Config.World.PlotCount do PlotBuilder.build(i, Layout.plotCFrame(i), world) end
end)
print(("8 plots (incl. tier-1 houses): %d (%d each)"):format(plots, plots // 8))
local gates = delta(function()
	for _, b in Biomes.List do Gate.build(b, Layout.gateCFrame(b.Index), world) end
end)
print(("15 gates: %d"):format(gates))
local biomeTotal, trailTotal, spotTotal, minGap = 0, 0, 0, math.huge
for _, b in Biomes.List do
	local skeletonParts, spots
	local n = delta(function()
		local ctx = Kit.newCtx(b, Layout.biomeCFrame(b.Index), world)
		require(Server.World.Builders.Biomes[b.Id])(ctx)
		skeletonParts = delta(function()
			local list = Kit.skeleton(ctx).spots
			spots = #list
			for i = 1, #list do
				for j = i + 1, #list do
					local gap = (list[i].cf.Position - list[j].cf.Position).Magnitude
					minGap = math.min(minGap, gap)
					assert(gap >= 8, ("%s spots %d and %d only %.1f studs apart"):format(b.Id, i, j, gap))
				end
			end
		end)
	end)
	spotTotal += spots
	local g = delta(function() GuardianRig.build(Guardians.ByBiome[b.Id], CFrame.new(0, 0, 0), world) end)
	biomeTotal += n + g
	print(("  %-17s %4d parts (terrain+props %d, skeleton %d, %d dig spots), guardian %d"):format(b.Id, n + g, n - skeletonParts, skeletonParts, spots, g))
end
trailTotal = (#Layout.biomePath(1) - 1) * #Biomes.List
print(("15 biomes incl. guardians: %d"):format(biomeTotal))
print(("Dig spots: %d (closest pair in any biome %.1f studs, need >= 8)"):format(spotTotal, minGap))
print(("Trails: %d segments"):format(trailTotal))
print(("World total at boot: ~%d parts (+ planted plant models at runtime)"):format(Parts.count() + trailTotal))
print(("Halloween decor (only while the event is active): %d"):format(delta(function()
	require(Server.World.Builders.Events.Halloween).build(world)
end)))

print("\n== Roster ==")
local rarityCount = {}
for _, b in Biomes.List do
	local list = Plants.ByBiome[b.Id] or {}
	local names = {}
	for _, p in list do
		table.insert(names, ("%s(%s/%s%s)"):format(p.Id, p.Rarity, p.Combat.Role, if p.WaterDependent then ",water" else ""))
		rarityCount[p.Rarity] = (rarityCount[p.Rarity] or 0) + 1
	end
	assert(#list >= 3, b.Id .. " has fewer than 3 species")
	print(("%2d %-17s %d: %s"):format(b.Index, b.Id, #list, table.concat(names, " ")))
end
local rc = {}
for _, r in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Divine" } do
	table.insert(rc, ("%s=%d"):format(r, rarityCount[r] or 0))
end
print("Rarity spread: " .. table.concat(rc, " ") .. (" (total %d)"):format(#Plants.List))

print("\n== Drop odds (exact, from weights) ==")
local function odds(biomeId, luck)
	local list = DropTables.weighted(biomeId, luck)
	local total = 0
	for _, d in list do total += d.Weight end
	local out = {}
	for _, d in list do table.insert(out, ("%s %.3f%%"):format(d.Plant, d.Weight / total * 100)) end
	return table.concat(out, ", ")
end
for _, id in { "GreenMeadows", "AncientWilds", "CosmicGarden", "ForbiddenBloom" } do
	print(("%s luck 0:   %s"):format(id, odds(id, 0)))
	print(("%s luck max: %s"):format(id, odds(id, Upgrades.Shovels[#Upgrades.Shovels].LuckBonus)))
end
print(("Luck clamp: weighted(luck=5) == weighted(MaxLuck=%s): %s"):format(Config.Dig.MaxLuck,
	tostring(odds("CosmicGarden", 5) == odds("CosmicGarden", Config.Dig.MaxLuck))))
-- Exclusivity: every drop belongs to its biome.
for biomeId, list in DropTables.ByBiome do
	for _, d in list do assert(Plants.ById[d.Plant].Biome == biomeId, "non-exclusive drop " .. d.Plant) end
end
print("Exclusivity: every drop table only contains its own biome's species: OK")
-- Roll sampling with a seeded RNG.
local rng = Random.new(12345)
local hits = {}
for _ = 1, 200000 do
	local d = DropTables.roll("ForbiddenBloom", 0, rng:NextNumber())
	hits[d.Rarity] = (hits[d.Rarity] or 0) + 1
end
print(("ForbiddenBloom 200k rolls, luck 0: Legendary %d, Mythical %d, Divine %d"):format(hits.Legendary or 0, hits.Mythical or 0, hits.Divine or 0))

print("\n== Pacing: minutes to afford the next biome ==")
-- Garden = house slots at the house tier you can own by then; every plant is a typical drop of
-- the newest biome: weighted-average rarity multiplier x average size multiplier (2.25).
local Rarities = require(Shared.Rarities)
local Sizes = require(Shared.Sizes)
local sizeAvg, wsum = 0, 0
for _, s in Sizes.List do sizeAvg += s.Multiplier * s.Weight; wsum += s.Weight end
sizeAvg /= wsum
-- Each step also waits one growth cycle: the refilled garden earns nothing until the newest
-- biome's plants (drop-weighted average GrowSeconds) are grown.
local total, totalGrow, lastPerPlant = 0, 0, 0
local steps = {}
for i = 1, #Biomes.List - 1 do
	local b, nextB = Biomes.List[i], Biomes.List[i + 1]
	local slots = Houses.List[1].Slots
	for _, h in Houses.List do if h.RequiredBiome <= i then slots = h.Slots end end
	local num, den, grow = 0, 0, 0
	for _, d in DropTables.ByBiome[b.Id] do
		local p = Plants.ById[d.Plant]
		num += d.Weight * p.BaseIncome * Rarities.ById[p.Rarity].Multiplier
		grow += d.Weight * p.GrowSeconds
		den += d.Weight
	end
	grow /= den
	local income = slots * (num / den) * sizeAvg
	local perPlant = income / slots
	local mins = (grow + nextB.Cost / income) / 60
	print(("%2d -> %2d  %-17s slots %2d  ~$%s/s  per plant ~$%s/s  next cost $%s  grow %.1f min  ~%.1f min"):format(i, i + 1, b.Id, slots,
		tostring(math.floor(income)), tostring(math.floor(perPlant)), tostring(nextB.Cost), grow / 60, mins))
	total += mins
	totalGrow += grow / 60
	table.insert(steps, ("%.1f"):format(mins))
	assert(perPlant >= lastPerPlant * 0.999, "per-plant income fell at biome " .. b.Id)
	lastPerPlant = perPlant
end
print(("Total ~%.0f min (~%.1f h) including %.0f min of growth; excludes refill walks and house purchases"):format(total, total / 60, totalGrow))
print("Minutes row: " .. table.concat(steps, " | "))

print("\n== Treadmill, speed and saved data ==")
do
	local Speed = require(Shared.Speed)
	local Treadmill = require(Shared.Treadmill)
	local Format = require(Shared.Format)
	local Schema = require(Server.Data.Schema)
	assert(Speed.walkSpeedFor(0) == 16, "walkSpeedFor(0) must be 16")
	assert(Speed.walkSpeedFor(1e15) <= 40.1 and Speed.walkSpeedFor(1e15) >= 39.9, "walkSpeedFor(1e15) ~40")
	local prev = -1
	for e = 0, 20, 0.25 do
		local w = Speed.walkSpeedFor(10 ^ e)
		assert(w >= prev, "walkSpeedFor must be monotonic")
		prev = w
	end
	assert(#Treadmill.Levels >= 30 and Treadmill.Levels[1].Cost == 0)
	for l = 2, #Treadmill.Levels do
		local a, b = Treadmill.Levels[l - 1], Treadmill.Levels[l]
		assert(b.Level == l and b.SpeedPerSec > a.SpeedPerSec and b.Cost > a.Cost, "level " .. l .. " must increase")
	end
	assert(Treadmill.nextCost(#Treadmill.Levels) == nil and Treadmill.multiplierFor("Nope") == 1)
	local top = Treadmill.Levels[#Treadmill.Levels]
	print(("%d levels: Lv2 %s/s for $%s ... Lv%d %s/s for $%s"):format(#Treadmill.Levels, Format.short(Treadmill.Levels[2].SpeedPerSec),
		Format.short(Treadmill.Levels[2].Cost), top.Level, Format.short(top.SpeedPerSec), Format.short(top.Cost)))
	print(("walkSpeed: 0 -> %.1f, 1K -> %.1f, 1B -> %.1f, 1e15 -> %.1f"):format(Speed.walkSpeedFor(0), Speed.walkSpeedFor(1e3), Speed.walkSpeedFor(1e9), Speed.walkSpeedFor(1e15)))
	assert(Format.short(96000) == "96K" and Format.short(1.2e15) == "1.2QA" and Format.money(2e15) == "$2QA")

	-- v6 record: no speed/trails; a partial trails record keeps its owned map and gains Starter.
	local v6 = Schema.default()
	v6.version = 6
	v6.speed, v6.treadmillLevel, v6.trails = nil, nil, nil
	local m = assert(Schema.migrate(v6))
	assert(m.version == Config.Data.SchemaVersion and m.speed == 0 and m.treadmillLevel == 1)
	assert(m.trails.owned.Starter == true and m.trails.equipped == "Starter")
	assert(m.trails.owned ~= Schema.default().trails.owned)
	local v7 = Schema.default()
	v7.trails = { owned = { Neon = true }, equipped = "Neon" }
	local m7 = assert(Schema.migrate(v7))
	assert(m7.trails.owned.Neon and m7.trails.owned.Starter and m7.trails.equipped == "Neon")
	local bad = Schema.default()
	bad.version = 6
	bad.trails = "junk"
	assert(assert(Schema.migrate(bad)).trails.owned.Starter)
	print("schema v6 -> v7 migration ok")

	-- Treadmill footprint (plot local) must clear the garden, every house tier and the spawn.
	local scratch = newInstance("Folder", "Scratch")
	local refs = PlotBuilder.build(99, CFrame.new(0, 0, 0), scratch)
	local function box(p) return p.CFrame.Position - p.Size / 2, p.CFrame.Position + p.Size / 2 end
	local function overlap(aMin, aMax, bMin, bMax)
		return aMin.X < bMax.X and aMax.X > bMin.X and aMin.Z < bMax.Z and aMax.Z > bMin.Z
	end
	local P = Config.Plot
	local gMin = Vector3.new(P.GardenOriginX - 1, 0, -P.Lanes * P.TileSize / 2 - 1)
	local gMax = Vector3.new(P.GardenOriginX + P.Columns * P.TileSize + 1, 0, P.Lanes * P.TileSize / 2 + 1)
	local n = 0
	for _, part in refs.treadmill:GetDescendants() do
		if part:IsA("BasePart") then
			n += 1
			local a, b = box(part)
			assert(not overlap(a, b, gMin, gMax), part.Name .. " overlaps the garden")
			for _, h in Houses.List do
				local hMin = Vector3.new(P.HouseX - h.Size.X / 2, 0, -h.Size.Z / 2)
				local hMax = Vector3.new(P.HouseX + h.Size.X / 2, 0, h.Size.Z / 2)
				assert(not overlap(a, b, hMin, hMax), part.Name .. " overlaps house " .. h.Name)
			end
			assert(a.X >= -P.Width / 2 and b.X <= P.Width / 2 and a.Z >= -P.Depth / 2 and b.Z <= P.Depth / 2, part.Name .. " leaves the plot")
			assert(not overlap(a, b, refs.spawn.Position - Vector3.new(3, 0, 3), refs.spawn.Position + Vector3.new(3, 0, 3)), part.Name .. " blocks the spawn")
		end
	end
	assert(refs.belt and refs.treadmillLevelLabel.Text == "Lv. 1 > Lv. 2" and refs.treadmillMoneyLabel.Text == "$230")
	PlotBuilder.setTreadmill(refs, Treadmill.MaxLevel)
	assert(refs.treadmillMoneyLabel.Text == "MAX")
	print(("treadmill + sign: %d parts per plot, clear of garden, houses, spawn"):format(n))
end

print("\n== Shops: trails, shovels, v8 data, hub stalls ==")
do
	local Trails = require(Shared.Trails)
	local Treadmill = require(Shared.Treadmill)
	local Schema = require(Server.Data.Schema)
	local want = {
		{ "Starter", 0, 1 }, { "Nature", 5000, 2 }, { "Lightning", 50000, 4 }, { "Inferno", 250000, 6 },
		{ "Mystic", 1000000, 8 }, { "Rainbow", 5000000, 12 }, { "Golden", 25000000, 18 }, { "Galaxy", 100000000, 25 },
		{ "Void", 500000000, 35 }, { "Divine", 2500000000, 50 },
	}
	assert(#Trails.List == 10, "need 10 trails")
	for i, w in want do
		local t = Trails.List[i]
		assert(t.Id == w[1] and t.Price == w[2] and t.Multiplier == w[3] and Trails.ById[w[1]] == t, "trail " .. i .. " mismatch")
		assert(Treadmill.multiplierFor(t.Id) == w[3] and #t.Colors >= 2 and t.Kind ~= "")
	end
	print("10 trails: ids, prices and multipliers exact; Treadmill.multiplierFor reads Shared.Trails")

	local shovelWant = {
		{ "Starter Shovel", 0 }, { "Steel Shovel", 25000 }, { "Crystal Shovel", 250000 }, { "Inferno Shovel", 2500000 },
		{ "Emerald Shovel", 25000000 }, { "Plasma Shovel", 250000000 }, { "Toxic Shovel", 2500000000 },
		{ "Ancient Shovel", 25000000000 }, { "Cosmic Shovel", 250000000000 }, { "Divine Shovel", 2500000000000 },
	}
	assert(#Upgrades.Shovels == 10, "need 10 shovels")
	local dmg = {}
	for i, w in shovelWant do
		local s = Upgrades.Shovels[i]
		assert(s.Tier == i and s.Name == w[1] and s.Cost == w[2], "shovel " .. i .. " mismatch")
		assert(s.ToughTier == math.min(i, 5) and s.LuckBonus <= Config.Dig.MaxLuck and s.Material ~= nil and s.Accent ~= nil)
		if i > 1 then
			local p = Upgrades.Shovels[i - 1]
			assert(s.Damage > p.Damage and s.DigSeconds < p.DigSeconds and s.LuckBonus >= p.LuckBonus and s.Cost > p.Cost, "shovel " .. i .. " must improve")
		end
		table.insert(dmg, tostring(s.Damage))
	end
	assert(Upgrades.Shovels[1].DigSeconds == 3 and Upgrades.Shovels[10].DigSeconds == 0.5 and Upgrades.Shovels[10].LuckBonus == Config.Dig.MaxLuck)
	print("10 shovels: names and prices exact; damage " .. table.concat(dmg, ",") .. "; dig 3s -> 0.5s; luck 0 -> " .. Config.Dig.MaxLuck)

	assert(Config.Data.SchemaVersion >= 8)
	local v7 = Schema.default()
	v7.version, v7.shovelTier, v7.shovels = 7, 4, nil
	v7.trails = { owned = { Starter = true, Nature = true }, equipped = "Nature" }
	local m = assert(Schema.migrate(v7))
	assert(m.version == Config.Data.SchemaVersion and m.shovels.equipped == 4 and m.shovelTier == 4)
	for t = 1, 10 do
		assert((m.shovels.owned[tostring(t)] == true) == (t <= 4), "v7 tier 4 must own exactly 1..4")
	end
	assert(m.trails.equipped == "Nature" and m.trails.owned.Nature)
	for k in m.shovels.owned do assert(type(k) == "string", "owned keys must be strings for DataStore") end
	local junk = Schema.default()
	junk.version, junk.shovelTier = 7, "x"
	local mj = assert(Schema.migrate(junk))
	assert(mj.shovels.equipped == 1 and mj.shovels.owned["1"])
	local v8 = Schema.default()
	v8.shovels = { owned = { ["1"] = true, ["3"] = true }, equipped = 7 }
	local m8 = assert(Schema.migrate(v8))
	assert(m8.shovels.equipped == 1 and m8.shovelTier == 1 and m8.shovels.owned["3"], "unowned equipped falls back")
	local bad = Schema.default()
	bad.shovels = "junk"
	assert(assert(Schema.migrate(bad)).shovels.owned["1"])
	local fresh = Schema.default()
	assert(fresh.shovels.equipped == 1 and fresh.shovels.owned["1"] and fresh.shovels.owned ~= Schema.default().shovels.owned)
	print("schema v7 -> v8 migration keeps shovel progress (tier 4 -> owns 1..4, equips 4); bad records repaired")

	-- Footprints: discs/cylinders by diameter, everything else by its larger horizontal side.
	local DISCS = { FountainBase = true, FountainWater = true, Plaza = true, ShopCircle = true }
	local function foot(p)
		local half = if DISCS[p.Name] then math.max(p.Size.Y, p.Size.Z) / 2 else math.max(p.Size.X, p.Size.Z) / 2
		local c = p.CFrame.Position
		return c.X - half, c.X + half, c.Z - half, c.Z + half
	end
	local function hits(a, b)
		local ax0, ax1, az0, az1 = foot(a)
		local bx0, bx1, bz0, bz1 = foot(b)
		return ax0 < bx1 and ax1 > bx0 and az0 < bz1 and az1 > bz0
	end
	local scratch = newInstance("Folder", "ShopScratch")
	local hub = Hub.build(scratch)
	local decor = require(Server.World.Builders.Events.Halloween).build(scratch)
	local stallParts, others = {}, {}
	for _, d in hub:GetDescendants() do
		if d:IsA("BasePart") then
			local inStall = false
			local node = d.Parent
			while node do
				if type(node.Name) == "string" and node.Name:match("^Stall_") then inStall = true end
				node = node.Parent
			end
			if inStall then
				table.insert(stallParts, d)
			elseif d.Name ~= "Baseplate" and d.Name ~= "Plaza" and d.Name ~= "PlotPath" then
				table.insert(others, d)
			end
		end
	end
	for _, d in decor:GetDescendants() do
		if d:IsA("BasePart") then table.insert(others, d) end
	end
	local circlesSeen = {}
	for _, s in stallParts do
		if s.Name == "ShopCircle" then
			circlesSeen[s:GetAttribute("ShopId")] = s:GetAttribute("Radius")
			local title = s:FindFirstChild("Title")
			assert(title and title:FindFirstChildOfClass("TextLabel"), "stall title missing")
		end
		for _, o in others do
			assert(not hits(s, o), ("%s (%s) overlaps %s"):format(s.Name, s.Parent.Name, o.Name))
		end
	end
	assert(circlesSeen.Trails == Config.Shops.Radius and circlesSeen.Shovels == Config.Shops.Radius, "both circles tagged")
	local P = Config.Plot
	for i = 1, Config.World.PlotCount do
		local c = Layout.plotCFrame(i).Position
		for _, s in stallParts do
			local x0, x1, z0, z1 = foot(s)
			assert(not (x0 < c.X + P.Width / 2 and x1 > c.X - P.Width / 2 and z0 < c.Z + P.Depth / 2 and z1 > c.Z - P.Depth / 2), s.Name .. " overlaps plot " .. i)
		end
	end
	local labels = {}
	for _, s in stallParts do
		if s.Name == "ShopCircle" then
			labels[s:GetAttribute("ShopId")] = s:FindFirstChild("Title"):FindFirstChildOfClass("TextLabel").Text
		end
	end
	assert(labels.Trails == "Trails Shop" and labels.Shovels == "Shovel Shop")
	print(("hub stalls: %d parts (%d each), clear of %d hub/Halloween parts (machines, spawn, fountain, trees) and all 8 plots"):format(#stallParts, #stallParts // 2, #others))
end

print("\n-- Biome banner data and shared regions --")
do
	local Format = require(Shared.Format)
	local BiomeRegions = require(Shared.BiomeRegions)
	local BiomesSrv = require(Server.Biomes)
	local want = {
		{ "GreenMeadows", "🌱", 100, "100" }, { "MushroomForest", "🍄", 10_000, "10K" },
		{ "CactusCanyon", "🌵", 100_000, "100K" }, { "InfernoJungle", "🔥", 1e6, "1M" },
		{ "FrostbiteGarden", "❄️", 1e7, "10M" }, { "EnchantedGrove", "🌳", 1e8, "100M" },
		{ "TropicalParadise", "🌴", 1e9, "1B" }, { "CoralKingdom", "🪸", 5e9, "5B" },
		{ "AutumnWoods", "🍂", 1e10, "10B" }, { "SkyIslands", "☁️", 2.5e10, "25B" },
		{ "CrystalCaverns", "💎", 5e10, "50B" }, { "ToxicSwamp", "☣️", 1e11, "100B" },
		{ "AncientWilds", "🏛️", 2.5e11, "250B" }, { "CosmicGarden", "🌌", 5e14, "500T" },
		{ "ForbiddenBloom", "🌺", 1e15, "1 QA" },
	}
	assert(#Biomes.List == 15)
	local shown = {}
	for i, w in want do
		local b = Biomes.List[i]
		assert(b.Id == w[1] and b.Emoji == w[2] and b.RecommendedSpeed == w[3], "banner data " .. b.Id)
		assert(Format.speed(b.RecommendedSpeed) == w[4], b.Id .. " speed text " .. Format.speed(b.RecommendedSpeed))
		table.insert(shown, Format.speed(b.RecommendedSpeed))
	end
	assert(Format.money(1e15) == "$1QA" and Format.short(1e15) == "1QA", "money/short formatting unchanged")

	-- Reference: the pre-move Layout + server `inside` math, written out from Config.
	local B, W = Config.Biome, Config.World
	local function refCenterZ(i) return Config.Plot.Depth / 2 + B.FrontGap + B.Size / 2 + (i - 1) * (B.Size + B.Gap) end
	local function refRegion(pos)
		for _, b in Biomes.List do
			local lp = pos - Vector3.new(0, W.GroundY, refCenterZ(b.Index))
			local half = B.Size / 2 + 1
			if math.abs(lp.X) <= half and math.abs(lp.Z) <= half and lp.Y > -20 and lp.Y < 120 then return b.Id end
		end
		return nil
	end
	local n, inside, outside = 0, 0, 0
	local function check(pos, expectNil)
		local s, r = BiomesSrv.regionOf(pos), BiomeRegions.regionOf(pos)
		assert(s == r and r == refRegion(pos), ("regionOf mismatch at %.1f,%.1f,%.1f"):format(pos.X, pos.Y, pos.Z))
		if expectNil then assert(r == nil, ("expected no region at %.1f,%.1f,%.1f"):format(pos.X, pos.Y, pos.Z)) end
		if r then
			inside += 1
			assert(BiomesSrv.inRegion(r, pos) and BiomeRegions.distanceInside(r, pos) >= 0)
		else
			outside += 1
		end
		n += 1
	end
	for _, b in Biomes.List do
		local cz = refCenterZ(b.Index)
		assert(Layout.biomeCenterZ(b.Index) == cz and Layout.biomeCFrame(b.Index).Position.Z == cz)
		for _, dz in { -58, -57.5, -57, -56.5, -56, -30, 0, 30, 56, 56.5, 57, 57.5, 58 } do
			for _, dx in { -58, -57, -56, 0, 56, 57, 58 } do
				for _, dy in { -21, -19, 0, 3, 119, 121 } do
					check(Vector3.new(dx, W.GroundY + dy, cz + dz))
				end
			end
		end
		local p = Vector3.new(0, W.GroundY + 3, cz)
		assert(math.abs(BiomeRegions.distanceInside(b.Id, p) - math.min(B.Size / 2 + 1, 3 + 20)) < 1e-6, "Y band is an edge")
		assert(math.abs(BiomeRegions.distanceInside(b.Id, p + Vector3.new(0, 0, 56.5)) - 0.5) < 1e-6, "hysteresis band")
		assert(BiomeRegions.distanceInside(b.Id, p + Vector3.new(0, 0, 58)) < 0)
		if b.Index > 1 then
			check(Vector3.new(0, W.GroundY + 3, cz - B.Size / 2 - B.Gap / 2), true) -- trail gap
		end
		local sc = BiomeRegions.safeCenter(b.Id)
		assert(sc and sc.Z == cz - B.Size / 2 + B.SafeRadius + 6 and sc.X == 0)
		assert(BiomesSrv.inSafeZone(b.Id, sc + Vector3.new(B.SafeRadius - 0.1, 0, 0)))
		assert(not BiomesSrv.inSafeZone(b.Id, sc + Vector3.new(B.SafeRadius + 0.1, 0, 0)))
	end
	check(Vector3.new(0, W.GroundY + 3, -70), true) -- hub spawn
	check(Vector3.new(0, W.GroundY + 3, Config.Plot.Depth / 2 + 6), true) -- trail to biome 1
	for i = 1, W.PlotCount do
		local pc = Layout.plotCFrame(i).Position
		check(pc + Vector3.new(0, 3, 0), true)
		check(pc + Vector3.new(Config.Plot.Width / 2 - 1, 3, Config.Plot.Depth / 2 - 1), true)
	end
	print(("  15 biomes: emoji + RecommendedSpeed exact; speed text %s"):format(table.concat(shown, ", ")))
	print(("  regionOf: server == shared == pre-move math at %d points (%d inside, %d outside); hub, plots, trail gaps -> nil"):format(n, inside, outside))
end

print("\n== Guardian chase: speed, v9 migration, carry state machine ==")
do
	local Speed = require(Shared.Speed)
	local Schema = require(Server.Data.Schema)
	local CCore = require(Server.Carry.Core)
	local G = Config.Guardian
	assert(G.SpeedFactor == 0.97 and G.PatrolFactor == 0.5 and G.MaxChaseSeconds == 60 and Config.Carry.SpeedFactor == 0.9)
	assert(Guardians.ByBiome.MushroomForest.Name == "Fungal Brute", "Mushroom Forest guardian is Fungal Brute")
	local names, prev = {}, -1
	print("  biome              rec speed  player  guardian  patrol  carrying  margin(carry)")
	for _, b in Biomes.List do
		local gd = Guardians.ByBiome[b.Id]
		assert(gd and not names[gd.Name], "unique guardian per biome: " .. b.Id)
		names[gd.Name] = true
		local player = Speed.walkSpeedFor(b.RecommendedSpeed)
		local gs = Speed.guardianSpeedFor(b.RecommendedSpeed)
		assert(gs >= prev, "guardianSpeedFor must be monotonic at " .. b.Id)
		assert(gs >= 15.5 and gs <= 40, ("%s guardian speed %.2f outside 15.5..40"):format(b.Id, gs))
		assert(player > gs, b.Id .. ": a player at recommended speed must outrun the guardian")
		prev = gs
		local carry = player * Config.Carry.SpeedFactor
		print(("  %-17s %10s  %6.2f  %8.2f  %6.2f  %8.2f  %+6.2f"):format(b.Id, tostring(b.RecommendedSpeed), player, gs, gs * G.PatrolFactor, carry, carry - gs))
	end
	assert(#Guardians.List == 15)

	local v8 = Schema.default()
	v8.version = 8
	v8.seeds = { Sunpetal = 2 }
	v8.expedition = { Sunpetal = 3, PeaPopper = 1, Bogus = "x" }
	local m = assert(Schema.migrate(v8))
	assert(m.version == 9 and Config.Data.SchemaVersion == 9)
	assert(m.seeds.Sunpetal == 5 and m.seeds.PeaPopper == 1 and m.seeds.Bogus == nil, "bag banked into seeds")
	assert(next(m.expedition) == nil, "expedition stays empty")
	local again = assert(Schema.migrate(m))
	assert(again.seeds.Sunpetal == 5, "re-migrating a v9 record changes nothing")
	local noBag = Schema.default()
	noBag.version, noBag.expedition = 8, nil
	assert(next(assert(Schema.migrate(noBag)).expedition) == nil)
	print("  schema v8 -> v9: expedition {Sunpetal 3, PeaPopper 1} + seeds {Sunpetal 2} -> seeds {Sunpetal 5, PeaPopper 1}, bag empty")

	local s = CCore.new(20, 20)
	local p0 = Vector3.new(0, 0, 0)
	local a = CCore.reveal(s, "alice", "Sunpetal", "Common", "GreenMeadows", p0, 0)
	assert(a.state == "revealed" and a.expiresAt == 20)
	local _, why = CCore.pickup(s, "bob", a.id, 1)
	assert(why == "not yours", "only the owner picks up")
	assert(CCore.pickup(s, "alice", a.id, 1) == a and a.state == "carried" and CCore.carried(s, "alice") == a)
	local _, why2 = CCore.pickup(s, "alice", a.id, 1)
	assert(why2 == "taken", "second pickup of the same seed fails")
	local b2 = CCore.reveal(s, "alice", "PeaPopper", "Rare", "GreenMeadows", p0, 1)
	local _, why3 = CCore.pickup(s, "alice", b2.id, 2)
	assert(why3 == "already carrying", "one seed at a time")
	assert(#CCore.expire(s, 100) == 1 and s.items[b2.id] == nil and s.items[a.id], "revealed seed expires, carried never does")
	assert(CCore.drop(s, "alice", Vector3.new(5, 0, 5), 100) == a and a.state == "dropped" and a.expiresAt == 120)
	assert(CCore.carried(s, "alice") == nil and CCore.drop(s, "alice", p0, 100) == nil)
	assert(#CCore.expire(s, 119.9) == 0)
	assert(CCore.pickup(s, "alice", a.id, 110) == a and a.expiresAt == math.huge)
	assert(CCore.drop(s, "alice", p0, 110) and a.expiresAt == 130, "each drop restarts the full timer")
	-- One pickup wins when two players race for a seed both may take.
	s.canTake = function() return true end
	local w1 = CCore.pickup(s, "bob", a.id, 111)
	local w2, why4 = CCore.pickup(s, "carol", a.id, 111)
	assert(w1 == a and w2 == nil and why4 == "taken" and a.carrier == "bob")
	assert(CCore.transfer(s, "bob", "bob") == nil, "no self transfer")
	assert(CCore.transfer(s, "bob", "carol") == a and a.carrier == "carol" and CCore.carried(s, "bob") == nil and CCore.carried(s, "carol") == a)
	local c2 = CCore.reveal(s, "dave", "Sunpetal", "Common", "GreenMeadows", p0, 111)
	assert(CCore.pickup(s, "dave", c2.id, 111) == c2)
	assert(CCore.transfer(s, "carol", "dave") == nil and CCore.carried(s, "carol") == a, "no transfer onto a carrier")
	assert(CCore.bank(s, "carol") == a and s.items[a.id] == nil and CCore.carried(s, "carol") == nil)
	assert(CCore.bank(s, "carol") == nil and CCore.pickup(s, "carol", a.id, 112) == nil, "banked seed is gone")
	assert(CCore.drop(s, "dave", p0, 200) and #CCore.expire(s, 220) == 1 and next(s.items) == nil, "dropped seed gone at 0")
	local carriers = 0
	for _ in s.byCarrier do carriers += 1 end
	assert(carriers == 0, "no leftover carriers")
	print("  carry core: owner-only pickup, one seed each, one pickup wins, drop timer resets, transfer atomic, bank removes, expiry permanent")
end

print("\n== Defense: wave simulation (Defense.Core, real modules, dt 0.1s) ==")
local Core = require(Server.Defense.Core)
local Zombies = require(Shared.Zombies)
local Combat = require(Shared.Combat)
local D = Config.Defense
local houseX = Config.Plot.HouseX + Houses.List[1].Size.X / 2

-- Runs one wave on a field. `garden` maps tile key -> {species, size}. Returns a report.
local function runWave(night, biome, lanes, garden, seed)
	local r = Random.new(seed)
	local f = Core.newField(houseX, 1 + D.HpPerBiome * (biome - 1))
	for key, rec in garden do
		local lane, col = key:match("^(%d)_(%d)$")
		Core.setPlant(f, key, tonumber(lane), PlotBuilder.colX(tonumber(col)), Combat.plantStats(rec[1], rec[2], "Normal"))
	end
	local queue = Zombies.compose(night, biome, lanes, r)
	local interval = Config.DayNight.NightSeconds * D.SpawnWindow / #queue
	local rep = { total = #queue, spawned = 0, kills = 0, house = 0, houseHits = 0, wilts = 0, by = {}, laneOk = true, leftOnly = true, maxAlive = 0 }
	local lastX = {}
	local t, nextSpawn, id = 0, 3, 0
	while t < Config.DayNight.NightSeconds do
		if #queue > 0 and t >= nextSpawn and Core.alive(f) < D.MaxPerPlot then
			nextSpawn = t + interval
			id += 1
			local kind = table.remove(queue, 1)
			Core.addZombie(f, id, kind, r:NextInteger(1, lanes), Config.Plot.ZombieSpawnX + r:NextNumber() * D.LaneSpawnJitter, Zombies.stats(kind, biome, night), t)
			rep.spawned += 1
		end
		local ev = {}
		Core.step(f, 0.1, t, ev)
		for _, e in ev do
			if e.kind == "kill" then rep.kills += 1; rep.by[e.by] = (rep.by[e.by] or 0) + 1
			elseif e.kind == "house" then rep.house += e.amount; rep.houseHits += 1
			elseif e.kind == "wilt" then rep.wilts += 1 end
		end
		for zid, z in f.zombies do
			if z.lane < 1 or z.lane > lanes then rep.laneOk = false end
			if lastX[zid] and z.x > lastX[zid] + 1e-6 then rep.leftOnly = false end
			lastX[zid] = z.x
		end
		rep.maxAlive = math.max(rep.maxAlive, Core.alive(f))
		Core.sweep(f)
		t += 0.1
	end
	local ev = {}
	Core.dawn(f, ev)
	rep.leftAtDawn = #ev
	local wiltedAfter = 0
	for _, p in f.plants do if p.wilted then wiltedAfter += 1 end end
	rep.wiltedAfterDawn = wiltedAfter
	return rep
end

local function show(name, rep)
	local by = {}
	for k, v in rep.by do table.insert(by, k .. "=" .. v) end
	table.sort(by)
	print(("%-34s spawned %2d/%2d  killed %2d (%s)  house hits %d (-%d HP)  wilted %d  max alive %d  lanes ok %s  left-only %s  despawned at dawn %d  wilted after dawn %d"):format(
		name, rep.spawned, rep.total, rep.kills, table.concat(by, " "), rep.houseHits, math.floor(rep.house), rep.wilts, rep.maxAlive,
		tostring(rep.laneOk), tostring(rep.leftOnly), rep.leftAtDawn, rep.wiltedAfterDawn))
	assert(rep.laneOk and rep.leftOnly and rep.wiltedAfterDawn == 0 and rep.maxAlive <= D.MaxPerPlot)
end

local starter = { ["1_3"] = { "PeaPopper", "Medium" }, ["2_3"] = { "PeaPopper", "Medium" }, ["3_3"] = { "PeaPopper", "Medium" },
	["2_6"] = { "Thornwall", "Medium" }, ["1_1"] = { "Sunpetal", "Small" } }
show("Night 1, biome 1, 3 lanes, starter", runWave(1, 1, 3, starter, 7))
show("Night 1, biome 1, 3 lanes, no plants", runWave(1, 1, 3, {}, 7))
show("Night 5 (boss), biome 1, 3 lanes, starter", runWave(5, 1, 3, starter, 7))
local mixed = {}
for lane = 1, 5 do
	mixed[lane .. "_2"] = { "Capshroom", "Medium" }
	mixed[lane .. "_4"] = { "Sporelord", "Medium" }
	mixed[lane .. "_5"] = { "Puffcap", "Medium" }
	mixed[lane .. "_7"] = { "BarrelCactus", "Medium" }
end
show("Night 10, biome 3, 5 lanes, mixed roles", runWave(10, 3, 5, mixed, 11))

print("\n-- Role checks: one plant at col 3 vs one Walker; 10 s --")
local function duel(species, zLane, zX)
	local f = Core.newField(houseX, 1)
	Core.setPlant(f, "2_3", 2, PlotBuilder.colX(3), Combat.plantStats(species, "Medium", "Normal"))
	local z = Core.addZombie(f, 1, "Walker", zLane, zX, Zombies.stats("Walker", 1, 1), 0)
	z.speed = 0 -- hold position so range rules are what is tested
	local ev, t, shots = {}, 0, 0
	local maxHp = z.hp
	while t < 10 do
		Core.step(f, 0.1, t, ev)
		t += 0.1
	end
	for _, e in ev do if e.kind == "shot" or e.kind == "splash" then shots += 1 end end
	return maxHp - z.hp, shots, z
end
local px = PlotBuilder.colX(3)
for _, case in {
	{ "PeaPopper", 2, px + 30, "same lane, ahead, in range" },
	{ "PeaPopper", 3, px + 30, "other lane" },
	{ "PeaPopper", 2, px - 10, "behind the plant" },
	{ "PeaPopper", 2, px + 80, "same lane, out of range" },
	{ "SunspikeAgave", 2, px + 30, "rapid, same lane" },
	{ "Capshroom", 3, px + 10, "AoE, adjacent lane" },
	{ "Capshroom", 4, px + 10, "AoE, two lanes away" },
	{ "Puffcap", 2, px + 20, "slow, same lane" },
	{ "Sporelord", 2, px + 20, "burn, same lane" },
	{ "Sunpetal", 2, px + 10, "income-only" },
} do
	local dealt, shots = duel(case[1], case[2], case[3])
	print(("  %-14s %-28s damage %6.1f  attacks %d"):format(case[1], case[4], dealt, shots))
end
-- Slow and burn effects.
do
	local f = Core.newField(houseX, 1)
	Core.setPlant(f, "2_3", 2, px, Combat.plantStats("Puffcap", "Medium", "Normal"))
	local z = Core.addZombie(f, 1, "Tank", 2, px + 40, Zombies.stats("Tank", 1, 1), 0)
	local ev = {}
	Core.step(f, 0.1, 0, ev)
	local x0 = z.x
	Core.step(f, 1, 0.1, ev)
	print(("  Slow: Tank moved %.2f studs in 1 s (base speed %.1f, slowed x%.1f)"):format(x0 - z.x, z.speed, Combat.SlowFactor))
	local g = Core.newField(houseX, 1)
	Core.setPlant(g, "2_3", 2, px, Combat.plantStats("Sporelord", "Medium", "Normal"))
	local w = Core.addZombie(g, 1, "Tank", 2, px + 40, Zombies.stats("Tank", 1, 1), 0)
	w.speed = 0
	Core.step(g, 0.1, 0, ev)
	local hp1 = w.hp
	Core.removePlant(g, "2_3")
	Core.step(g, 1, 1, ev)
	print(("  Burn: Tank lost %.1f HP to burn in the 1 s after the plant was removed"):format(hp1 - w.hp))
end
-- Wall: blocks, thorns, wilts (not removed), recovers at dawn.
do
	local f = Core.newField(houseX, 1)
	Core.setPlant(f, "2_5", 2, PlotBuilder.colX(5), Combat.plantStats("Thornwall", "Medium", "Normal"))
	local z = Core.addZombie(f, 1, "Tank", 2, PlotBuilder.colX(5) + 4, Zombies.stats("Tank", 1, 1), 0)
	local ev, t, wiltAt = {}, 0, nil
	while t < 60 and not wiltAt do
		Core.step(f, 0.1, t, ev)
		for _, e in ev do if e.kind == "wilt" then wiltAt = t end end
		t += 0.1
	end
	local p = f.plants["2_5"]
	print(("  Wall: Thornwall (%d HP) held a Tank for %.1f s, thorns dealt %.0f, wilted=%s, still in field=%s"):format(
		p.maxHp, wiltAt or -1, Zombies.stats("Tank", 1, 1).hp - z.hp, tostring(p.wilted), tostring(f.plants["2_5"] ~= nil)))
	Core.dawn(f, {})
	print(("  Dawn: wilted=%s hp=%d/%d"):format(tostring(p.wilted), p.hp, p.maxHp))
end
-- Jumper vaults the first plant once; Spitter attacks from range.
do
	local f = Core.newField(houseX, 1)
	Core.setPlant(f, "2_6", 2, PlotBuilder.colX(6), Combat.plantStats("Sunpetal", "Medium", "Normal"))
	local j = Core.addZombie(f, 1, "Jumper", 2, PlotBuilder.colX(6) + 10, Zombies.stats("Jumper", 4, 1), 0)
	local s = Core.addZombie(f, 2, "Spitter", 2, PlotBuilder.colX(6) + 40, Zombies.stats("Spitter", 5, 1), 0)
	local ev, t, jumped, spitFrom = {}, 0, false, nil
	while t < 20 do
		Core.step(f, 0.1, t, ev)
		for _, e in ev do
			if e.kind == "jump" then jumped = true end
			if e.kind == "spit" and not spitFrom then spitFrom = e.zombie.x - e.plant.x end
		end
		t += 0.1
	end
	print(("  Jumper: vaulted=%s, now %.1f studs past the plant  Spitter: attacked from %.1f studs (range %d)"):format(
		tostring(jumped), PlotBuilder.colX(6) - j.x, spitFrom or -1, Zombies.stats("Spitter", 5, 1).range))
	local _ = s
end
-- Isolation: two plots' fields never share zombies.
do
	local a, b = Core.newField(houseX, 1), Core.newField(houseX, 1)
	Core.setPlant(b, "1_3", 1, px, Combat.plantStats("PeaPopper", "Medium", "Normal"))
	Core.addZombie(a, 1, "Walker", 1, px + 20, Zombies.stats("Walker", 1, 1), 0)
	local ev = {}
	for i = 0, 50 do Core.step(b, 0.1, i / 10, ev) end
	print(("  Isolation: plot B's plant fired %d times at plot A's zombie (expected 0)"):format(#ev))
	assert(#ev == 0)
end

print("\n-- Fairness: wave size by lanes, stats by biome --")
for _, lanes in { 3, 5, 7 } do
	print(("  %d lanes: night 1 %d, night 5 %d, night 12+ %d zombies (%.1f per lane at night 12)"):format(lanes,
		Zombies.waveSize(1, lanes), Zombies.waveSize(5, lanes), Zombies.waveSize(12, lanes), Zombies.waveSize(12, lanes) / lanes))
end
for _, k in { 1, 5, 10, 15 } do
	local w = Zombies.stats("Walker", k, 1)
	local pea = Plants.ByBiome[Biomes.List[k].Id]
	local best = 0
	for _, pl in pea do best = math.max(best, pl.Combat.Damage * pl.Combat.AttackRate) end
	print(("  biome %2d: Walker HP %d, dmg %.1f; best plant DPS in that biome %.1f"):format(k, w.hp, w.damage, best))
end

print("\n-- Fusion state machine --")
do
	local FCore = require(Server.Fusion.Core)
	local FData = require(Shared.Fusion)
	local function slot(u) return { unlocked = u, state = "empty", runId = 0, startedAt = 0, endsAt = 0 } end
	local prof = { plants = {}, nextItemId = 1, collection = {}, fusion = { Neon = slot(false), Mega = slot(false) } }
	for i = 1, 5 do
		prof.plants[tostring(i)] = { id = tostring(i), species = "PeaPopper", rarity = Plants.ById.PeaPopper.Rarity, size = "Medium", variant = "Normal" }
		prof.nextItemId = i + 1
	end
	prof.plants["9"] = { id = "9", species = "PeaPopper", rarity = "Common", size = "Large", variant = "Normal" }
	local ok = FCore.start(prof, "Neon", "PeaPopper", "Medium", 0)
	assert(not ok, "locked machine must refuse")
	prof.fusion.Neon.unlocked = true
	ok = FCore.start(prof, "Neon", "PeaPopper", "Medium", 100)
	assert(ok)
	local left = 0
	for _ in prof.plants do left += 1 end
	assert(left == 2 and prof.plants["5"] and prof.plants["9"], "exactly 4 same-size removed")
	assert(#(prof.fusion.Neon.ingredients :: any) == FData.InputCount)
	assert(not FCore.start(prof, "Neon", "PeaPopper", "Medium", 101), "busy machine refuses")
	local run = prof.fusion.Neon.runId
	assert(FCore.status(prof.fusion.Neon, 101) == "fusing")
	local early = FCore.claim(prof, "Neon", run, 101)
	assert(early == nil, "cannot claim while fusing")
	local done = prof.fusion.Neon.endsAt
	assert(FCore.status(prof.fusion.Neon, done + 3600) == "ready", "offline completion by timestamp")
	local id1, g1 = FCore.claim(prof, "Neon", run, done)
	local id2, g2 = FCore.claim(prof, "Neon", run, done + 1)
	local neon = 0
	for _, it in prof.plants do if it.variant == "Neon" then neon += 1 end end
	assert(g1 and not g2 and id1 == id2 and neon == 1, "double claim grants once")
	assert(prof.fusion.Neon.state == "empty" and prof.collection["PeaPopper|Neon"])
	print(("  start removes 4 (left %d), claim granted=%s, repeat granted=%s, Neon items=%d"):format(left, tostring(g1), tostring(g2), neon))
end

print("\n-- Receipt ledger --")
do
	local PCore = require(Server.Purchases.Core)
	local ledger = { order = {}, seen = {}, pending = {} }
	local grants, saves = 0, 0
	local function grant() grants += 1 end
	local function saveOk() saves += 1 return true end
	local r1 = PCore.process(ledger, "P1", "Skip", nil, saveOk, grant)
	local r2 = PCore.process(ledger, "P1", "Skip", nil, saveOk, grant)
	assert(r1 == "Granted" and r2 == "Granted" and grants == 1 and saves == 1, "same PurchaseId grants once")
	local r3 = PCore.process(ledger, "P2", "Skip", nil, function() return false end, grant)
	assert(r3 == "NotProcessedYet" and grants == 1 and not ledger.seen.P2, "failed save grants nothing")
	local r4 = PCore.process(ledger, "P3", "Skip", nil, function() error("ds down") end, grant)
	assert(r4 == "NotProcessedYet" and grants == 1, "erroring save grants nothing")
	local granted = false
	PCore.process(ledger, "P4", "Skip", nil, function() assert(not granted and ledger.pending.P4) return true end, function() granted = true end)
	assert(granted, "grant only after ledger written")
	ledger.seen.P5, ledger.pending.P5 = true, { key = "GrowthBoost" }
	local n = PCore.recover(ledger, grant)
	assert(n == 1 and grants == 2 and PCore.recover(ledger, grant) == 0, "recover applies pending once")
	print(("  P1 twice -> %d grant; failed/erroring save -> %s/%s; recover -> %d"):format(1, r3, r4, n))
end

print("\n-- Halloween event --")
do
	local Events = require(Shared.Events)
	local Products = require(Shared.Products)
	for _, e in Events.List do
		local sum = 0
		for _, row in Events.odds(e.Pack) do sum += row.Percent or row.Weight or 0 end
		local count = #(Plants.ByBiome[e.Biome] or {})
		print(("  %s: %d plants, odds sum %.2f%%, %d quests"):format(e.Id, count, sum, #e.Quests))
		assert(math.abs(sum - 100) < 1e-6 and count == 7 and #e.Quests == 3)
	end
	for _, p in Products.List do assert(not Products.enabled(p.Key) or p.Id ~= 0) end
end

print("\n-- Economy: income formula and size ordering (A3, A4) --")
do
	local Economy = require(Shared.Economy)
	local Rar = require(Shared.Rarities)
	local Sz = require(Shared.Sizes)
	local def = Plants.ById.PeaPopper
	local rec = { species = "PeaPopper", rarity = def.Rarity, size = "Medium", variant = "Normal" }
	local want = def.BaseIncome * Rar.ById[def.Rarity].Multiplier * Sz.ById.Medium.Multiplier
	assert(math.abs(Economy.incomeOf(rec) - want) < 1e-9, "income = base x rarity x size x variant")
	local last = -1
	for _, size in Sz.List do
		local inc = Economy.incomeOf({ species = "PeaPopper", rarity = def.Rarity, size = size.Id, variant = "Normal" })
		assert(inc > last, "larger size must earn more: " .. size.Id)
		last = inc
	end
	local neon = Economy.incomeOf({ species = "PeaPopper", rarity = def.Rarity, size = "Medium", variant = "Neon" })
	local mega = Economy.incomeOf({ species = "PeaPopper", rarity = def.Rarity, size = "Medium", variant = "Mega" })
	assert(neon > want and mega > neon, "variants raise income")
	print(("  PeaPopper Medium $%.2f/s (formula match), sizes strictly increasing to $%.2f/s, Neon x%.0f, Mega x%.0f"):format(
		want, last, neon / want, mega / want))
end

print("\n-- Offline growth and earnings by timestamps (A16) --")
do
	local Economy = require(Shared.Economy)
	local def = Plants.ById.PeaPopper
	local rec = { species = "PeaPopper", rarity = def.Rarity, size = "Medium", variant = "Normal", plantedAt = 1000 }
	local _, s0 = Economy.growth(rec, 1000, 1)
	local _, s1 = Economy.growth(rec, 1000 + def.GrowSeconds * 0.5, 1)
	local _, s2 = Economy.growth(rec, 1000 + def.GrowSeconds, 1)
	assert(s0 == 1 and s1 == 2 and s2 == 4, "stages advance from plantedAt alone")
	local _, fast = Economy.growth(rec, 1000 + def.GrowSeconds / 1.15, 1.15)
	assert(fast == 4, "water multiplier shortens growth")
	local away = 2 * 3600
	local earned, window = Economy.offlineEarnings({ a = rec }, 1000, 1000 + away, 1)
	local expect = math.floor(Economy.incomeOf(rec) * (away - def.GrowSeconds) * Config.Garden.OfflineRate)
	assert(earned == expect and window == away, "offline pays only after growth, at OfflineRate")
	local capped, capWindow = Economy.offlineEarnings({ a = rec }, 1000, 1000 + 1e7, 1)
	assert(capWindow == Config.Garden.OfflineCapHours * 3600 and capped > earned, "offline window is capped")
	assert(Economy.offlineEarnings({ a = rec }, 0, 5000, 1) == 0, "no lastSeen pays nothing")
	print(("  stages 1->2->4 by time; 2 h away earns $%d (window %d s, cap %d h)"):format(earned, window, Config.Garden.OfflineCapHours))
end

print("\n-- Biome access (A7, A8) --")
do
	local BiomesSrv = require(Server.Biomes)
	do
		local prof: any = { biomesUnlocked = {} }
		local first, second = Biomes.List[1], Biomes.List[2]
		assert(BiomesSrv.canEnter(prof, first.Id) == first.Released, "starter biome is free")
		assert(not BiomesSrv.canEnter(prof, second.Id), "locked biome refused")
		prof.biomesUnlocked[second.Id] = true
		assert(BiomesSrv.canEnter(prof, second.Id) == second.Released, "bought biome opens")
		local last = Biomes.List[#Biomes.List]
		prof.biomesUnlocked[last.Id] = true
		local was = last.Released
		last.Released = false
		assert(not BiomesSrv.canEnter(prof, last.Id), "unreleased biome refused even when owned")
		last.Released = was
		local released = 0
		for _, b in Biomes.List do if b.Released then released += 1 end end
		print(("  locked refused, bought allowed (stored in biomesUnlocked), unreleased refused even when owned; %d/15 released"):format(released))
	end
end

print("\n-- Save data: migration never wipes (A25) --")
do
	local Schema = require(Server.Data.Schema)
	local v1 = { version = 1, money = 12345, seeds = { ["PeaPopper|Common|Medium"] = 2, ["PeaPopper|Common|Large"] = 1 }, lanesUnlocked = 4,
		biomesUnlocked = { [Biomes.List[2].Id] = true } }
	local m = assert(Schema.migrate(v1))
	assert(m.money == 12345 and m.seeds.PeaPopper == 3 and m.lanesUnlocked == 4 and m.biomesUnlocked[Biomes.List[2].Id], "v1 keeps progress")
	assert(m.version == Config.Data.SchemaVersion and m.fusion.Neon ~= nil and m.receiptLedger.pending ~= nil, "reconciled to current schema")
	local newer, why = Schema.migrate({ version = Config.Data.SchemaVersion + 1, money = 5 })
	assert(newer == nil and why, "newer record is refused, not overwritten")
	assert(Schema.migrate("garbage") == nil, "corrupt record is refused")
	local fresh = assert(Schema.migrate(nil))
	assert(fresh.money == Schema.default().money)
	local v4 = assert(Schema.migrate({ version = 4, nextItemId = 7, planted = { ["1|1"] = { species = "PeaPopper", rarity = "Common", size = "Medium", variant = "Normal", plantedAt = 0 } } }))
	assert(v4.planted["1|1"].uid == "7" and v4.nextItemId == 8 and v4.purchaseIntent ~= nil, "v4 planted records get a uid")
	print(("  v1 -> v%d keeps money/seeds/lanes/biomes; v4 plants get uids; newer and corrupt records refused (%s)"):format(Config.Data.SchemaVersion, why))
end

print("\n-- Duplication guards in the pure cores (A22) --")
do
	local FCore = require(Server.Fusion.Core)
	local function slot() return { unlocked = true, state = "empty", runId = 0, startedAt = 0, endsAt = 0 } end
	local prof = { plants = {}, nextItemId = 4, collection = {}, fusion = { Neon = slot(), Mega = slot() } }
	for i = 1, 3 do
		prof.plants[tostring(i)] = { id = tostring(i), species = "PeaPopper", rarity = "Common", size = "Medium", variant = "Normal" }
	end
	assert(not FCore.start(prof, "Neon", "PeaPopper", "Medium", 0), "3 items cannot start")
	prof.plants["4"] = { id = "4", species = "PeaPopper", rarity = "Common", size = "Small", variant = "Normal" }
	assert(not FCore.start(prof, "Neon", "PeaPopper", "Medium", 0), "mixed sizes cannot start")
	assert(not FCore.start(prof, "Mega", "PeaPopper", "Medium", 0), "Mega refuses Normal inputs")
	local n = 0
	for _ in prof.plants do n += 1 end
	assert(n == 4, "refused starts remove nothing")
	assert(select(2, FCore.claim(prof, "Neon", 0, 1e9)) == false, "claim on empty grants nothing")
	assert(select(2, FCore.claim(prof, "Neon", 99, 1e9)) == false, "forged runId grants nothing")
	assert(not FCore.skip(prof, "Neon", 0), "skip on empty does nothing")
	print("  short, mixed-size, wrong-tier starts refused with inventory intact; empty/forged claims grant nothing")
end

print("\n-- Collection index data --")
do
	local Discovery = require(Shared.Discovery)
	local d = {
		collection = { ["PeaPopper|Neon"] = true },
		seeds = { Sunpetal = 1 },
		expedition = {},
		plants = { ["1"] = { species = "PeaPopper", variant = "Mega" } },
		planted = {},
	}
	local set = Discovery.of(d)
	assert(set["Sunpetal|Normal"] and set["PeaPopper|Mega"] and set["PeaPopper|Neon"])
	assert(Discovery.best(set, "PeaPopper") == "Mega" and Discovery.best(set, "Sunpetal") == "Normal")
	assert(Discovery.best(set, "ToxicVine") == nil)
	print("  held seeds and plants count as discovered; best variant Mega > Neon > Normal; unseen is locked")
end

print("\n-- Sounds --")
do
	local Sounds = require(Shared.Sounds)
	local missing = {}
	for _, k in { "Dig", "Discover", "Plant", "Buy", "Click", "Error", "NightWarning", "WaveClear", "FusionDone", "GuardianWarning", "Music" } do
		assert(Sounds.Ids[k] ~= nil, "sound table missing " .. k)
		if Sounds.uri(k) == nil then table.insert(missing, k) end
	end
	assert(Sounds.uri("NoSuchSound") == nil)
	print("  11 names present; no-op (id 0): " .. table.concat(missing, ", "))
end

print("\n-- Instant Grow targets one saved plant uid --")
do
	local PCore = require(Server.Purchases.Core)
	local function rec(uid) return { uid = uid, species = "PeaPopper", rarity = "Common", size = "Medium", variant = "Normal", plantedAt = 1000 } end
	local p: any = { planted = { ["1|1"] = rec("10"), ["1|2"] = rec("11") }, water = {}, growthBoostEndsAt = 0,
		credits = {}, purchaseIntent = { InstantGrow = "10" }, receiptLedger = { order = {}, seen = {}, pending = {} } }
	local function grantIG(_key, arg)
		if not PCore.instantGrow(p, arg, 1001) then p.credits.InstantGrow = (p.credits.InstantGrow or 0) + 1 end
	end
	assert(PCore.process(p.receiptLedger, "IG0", "InstantGrow", p.purchaseIntent.InstantGrow, function() return false end, grantIG) == "NotProcessedYet")
	assert(not p.planted["1|1"].matured and not p.credits.InstantGrow, "failed save grants nothing")
	p.planted["1|1"] = nil
	assert(PCore.process(p.receiptLedger, "IG1", "InstantGrow", p.purchaseIntent.InstantGrow, function() return true end, grantIG) == "Granted")
	assert(not p.planted["1|2"].matured, "no other plant finishes")
	assert(p.credits.InstantGrow == 1, "missing target banks one credit")
	assert(PCore.instantGrow(p, "11", 1001) == "1|2" and p.planted["1|2"].matured, "credit applies to a chosen growing plant")
	assert(PCore.instantGrow(p, nil, 1001) == nil, "no intent finishes nothing")
	print("  target gone -> 1 InstantGrow credit, other plant untouched; failed save grants nothing; credit applies later")
end

print("\n-- Halloween guardian exists only while the event is active --")
do
	local Events = require(Shared.Events)
	local Guardians = require(Shared.Guardians)
	local e = Events.ById.Halloween2026
	assert(e.Guardian and Guardians.Event.Halloween2026, "event zone and guardian def")
	assert(Events.guardianEvent(e.StartsAt + 60) == "Halloween2026")
	assert(Events.guardianEvent(e.StartsAt - 60) == nil and Events.guardianEvent(e.EndsAt + 60) == nil)
	local gm = Guardians.ByBiome[Biomes.List[1].Id]
	local hg = Guardians.Event.Halloween2026
	local Speed = require(Shared.Speed)
	local hs, gs = Speed.guardianSpeedFor(hg.RecommendedSpeed), Speed.guardianSpeedFor(Biomes.List[1].RecommendedSpeed)
	assert(hs > gs, "faster than Green Meadows")
	local ok, GuardianAI = pcall(require, Server.GuardianAI)
	assert(ok, "GuardianAI loads: " .. tostring(GuardianAI))
	assert(GuardianAI.eventGuardianCount() == 0)
	GuardianAI.setEventGuardian(Events.guardianEvent(e.StartsAt + 60))
	assert(GuardianAI.eventGuardianCount() == 1, "spawned while active")
	GuardianAI.setEventGuardian(Events.guardianEvent(e.EndsAt + 60))
	assert(GuardianAI.eventGuardianCount() == 0, "removed when the event ends")
	print(("  active -> 1 guardian, off -> 0; chase %.2f (Green Meadows %.2f)"):format(hs, gs))
end
'''


def bundle():
    entries = []
    for src_dir, mount in MAPS.items():
        base = os.path.join(ROOT, src_dir)
        for dirpath, _, files in os.walk(base):
            for f in files:
                if not f.endswith(".luau") or ".server." in f or ".client." in f:
                    continue
                rel = os.path.relpath(os.path.join(dirpath, f), base)
                name = rel[:-5]
                if os.path.basename(name) == "init":
                    name = os.path.dirname(name)
                path = mount + ("/" + name if name else "")
                with open(os.path.join(dirpath, f)) as fh:
                    src = fh.read()
                entries.append(f'["{path}"] = [=====[{src}]=====]')
    return "local SOURCES = {\n" + ",\n".join(entries) + "\n}\n"


def main():
    code = bundle() + "(function(...)\n" + RUNTIME + "\nend)(SOURCES)\n"
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as fh:
        fh.write(code)
        path = fh.name
    sys.exit(subprocess.call(["luau", path]))


if __name__ == "__main__":
    main()
