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
INST.__index = function(o, k)
	if methods[k] then return methods[k] end
	local child = methods.FindFirstChild(o, k)
	if child then return child end
	if k == "Changed" or k == "Touched" or k == "Activated" or k:match("Changed$") or k:match("Triggered$") then
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
local biomeTotal, trailTotal = 0, 0
for _, b in Biomes.List do
	local skeletonParts, spots
	local n = delta(function()
		local ctx = Kit.newCtx(b, Layout.biomeCFrame(b.Index), world)
		require(Server.World.Builders.Biomes[b.Id])(ctx)
		skeletonParts = delta(function() spots = #Kit.skeleton(ctx).spots end)
	end)
	local g = delta(function() GuardianRig.build(Guardians.ByBiome[b.Id], CFrame.new(0, 0, 0), world) end)
	biomeTotal += n + g
	print(("  %-17s %4d parts (terrain+props %d, skeleton %d, %d dig spots), guardian %d"):format(b.Id, n + g, n - skeletonParts, skeletonParts, spots, g))
end
trailTotal = (#Layout.biomePath(1) - 1) * #Biomes.List
print(("15 biomes incl. guardians: %d"):format(biomeTotal))
print(("Trails: %d segments"):format(trailTotal))
print(("World total at boot: ~%d parts (+ planted plant models at runtime)"):format(Parts.count() + trailTotal))

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
local total, lastPerPlant = 0, 0
for i = 1, #Biomes.List - 1 do
	local b, nextB = Biomes.List[i], Biomes.List[i + 1]
	local slots = Houses.List[1].Slots
	for _, h in Houses.List do if h.RequiredBiome <= i then slots = h.Slots end end
	local num, den = 0, 0
	for _, d in DropTables.ByBiome[b.Id] do
		local p = Plants.ById[d.Plant]
		num += d.Weight * p.BaseIncome * Rarities.ById[p.Rarity].Multiplier
		den += d.Weight
	end
	local income = slots * (num / den) * sizeAvg
	local perPlant = income / slots
	print(("%2d -> %2d  %-17s slots %2d  ~$%s/s  per plant ~$%s/s  next cost $%s  ~%.1f min"):format(i, i + 1, b.Id, slots,
		tostring(math.floor(income)), tostring(math.floor(perPlant)), tostring(nextB.Cost), nextB.Cost / income / 60))
	total += nextB.Cost / income / 60
	assert(perPlant >= lastPerPlant * 0.999, "per-plant income fell at biome " .. b.Id)
	lastPerPlant = perPlant
end
print(("Total ~%.0f min (~%.1f h) of income time, excluding growth, refills and house purchases"):format(total, total / 60))
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
