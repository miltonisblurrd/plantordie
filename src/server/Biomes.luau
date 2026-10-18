--!strict
-- Builds biome gates around the hub and anchors for P3 biome areas; answers unlock queries.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Data = require(script.Parent.Data)
local Layout = require(script.Parent.World.Layout)
local Gate = require(script.Parent.World.Builders.Gate)

local Biomes = {}

local gates: { [string]: Model } = {}
local anchors: { [string]: CFrame } = {}

function Biomes.isUnlocked(profile: Data.Profile, biomeId: string): boolean
	local b = BiomeData.ById[biomeId]
	return b ~= nil and (b.Cost == 0 or profile.biomesUnlocked[biomeId] == true)
end

-- Highest unlocked biome index (used later for zombie scaling and house tier gating).
function Biomes.highestUnlocked(profile: Data.Profile): number
	local best = 1
	for _, b in BiomeData.List do
		if Biomes.isUnlocked(profile, b.Id) then
			best = math.max(best, b.Index)
		end
	end
	return best
end

function Biomes.anchor(biomeId: string): CFrame?
	return anchors[biomeId]
end

function Biomes.gate(biomeId: string): Model?
	return gates[biomeId]
end

function Biomes.start(worldFolder: Instance)
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "Gates"
	gateFolder.Parent = worldFolder
	local anchorFolder = Instance.new("Folder")
	anchorFolder.Name = "BiomeAnchors"
	anchorFolder.Parent = worldFolder

	for _, b in BiomeData.List do
		gates[b.Id] = Gate.build(b, Layout.gateCFrame(b.Index), gateFolder)
		local cf = Layout.biomeAnchor(b.Index)
		anchors[b.Id] = cf
		local marker = Instance.new("Part")
		marker.Name = b.Id
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.Transparency = 1
		marker.Size = Vector3.new(1, 1, 1)
		marker.CFrame = cf
		marker:SetAttribute("BiomeIndex", b.Index)
		marker.Parent = anchorFolder
	end
end

return Biomes
