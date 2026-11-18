--!strict
-- Builds all 15 biome areas end to end with shared borders. Every released biome is open:
-- there are no gates and no purchase. Night difficulty still reads biomesUnlocked so opening
-- the world does not jump the portal to the last biome.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local BiomeRegions = require(ReplicatedStorage.Shared.BiomeRegions)
local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)
local Layout = require(script.Parent.World.Layout)
local Parts = require(script.Parent.World.Parts)
local Kit = require(script.Parent.World.BiomeKit)
local B = Config.Biome

export type BiomeInfo = {
	biome: BiomeData.Biome,
	cf: CFrame,
	model: Model,
	skeleton: Kit.Skeleton,
}

local Biomes = {}
Biomes.HubSpawn = CFrame.new(0, Config.World.GroundY + 4, -70)

local infos: { [string]: BiomeInfo } = {}

function Biomes.isUnlocked(_profile: Data.Profile, biomeId: string): boolean
	return BiomeData.ById[biomeId] ~= nil
end

-- Saved unlock flags only. Used for night scaling, not for keeping players out.
function Biomes.highestUnlocked(profile: Data.Profile): number
	local best = 1
	for _, b in BiomeData.List do
		if b.Cost == 0 or profile.biomesUnlocked[b.Id] == true then
			best = math.max(best, b.Index)
		end
	end
	return best
end

function Biomes.info(biomeId: string): BiomeInfo?
	return infos[biomeId]
end

function Biomes.anchor(biomeId: string): CFrame?
	local info = infos[biomeId]
	return info and info.cf
end

Biomes.regionOf = BiomeRegions.regionOf
Biomes.inRegion = BiomeRegions.inRegion

function Biomes.rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function Biomes.canEnter(_profile: Data.Profile, biomeId: string): boolean
	local b = BiomeData.ById[biomeId]
	return b ~= nil and b.Released
end

-- Boot-time layout checks: floors touch, every border is a wide doorway, dig spots sit on open
-- floor. A failure warns instead of stopping the server.
local function verifyLayout()
	local problems: { string } = {}
	for i = 2, BiomeData.Count do
		local seam = (Layout.biomeCenterZ(i) - B.Size / 2) - (Layout.biomeCenterZ(i - 1) + B.Size / 2)
		if math.abs(seam) > 0.01 then
			table.insert(problems, `gap of {seam} studs before biome {i}`)
		end
	end
	if B.Doorway < 120 or Config.World.BaseOpening < B.Doorway then
		table.insert(problems, "doorways are narrower than 120 studs")
	end
	for id, info in infos do
		for _, spot in info.skeleton.spots do
			if not Kit.spotIsOpen(info.cf, spot.cf.Position) then
				table.insert(problems, `{id} dig spot {spot.id} is off the open floor`)
			end
		end
	end
	if #problems > 0 then
		warn("[Biomes] layout check: " .. table.concat(problems, "; "))
	end
end

function Biomes.start(worldFolder: Instance)
	local biomeFolder = Instance.new("Folder")
	biomeFolder.Name = "Biomes"
	biomeFolder.Parent = worldFolder

	local builders = script.Parent.World.Builders.Biomes
	for _, b in BiomeData.List do
		local cf = Layout.biomeCFrame(b.Index)
		local before = Parts.count()
		local ctx = Kit.newCtx(b, cf, biomeFolder)
		local builderModule = builders:FindFirstChild(b.Id)
		assert(builderModule and builderModule:IsA("ModuleScript"), "Missing biome builder " .. b.Id)
		local build = (require :: any)(builderModule) :: (Kit.Ctx) -> ()
		build(ctx)
		infos[b.Id] = { biome = b, cf = cf, model = ctx.model, skeleton = Kit.skeleton(ctx) }
		local used = Parts.count() - before
		ctx.model:SetAttribute("PartCount", used)
		if used > Kit.PART_BUDGET then
			warn(`[Biomes] {b.Id} uses {used} parts (budget {Kit.PART_BUDGET})`)
		end
	end
	verifyLayout()
end

return Biomes
