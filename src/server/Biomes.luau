--!strict
-- Builds the biome gates and all 15 biome areas, end to end with shared borders; answers unlock and
-- region queries; and enforces locked regions on the server. Gate barriers are only a
-- client-side convenience: the region check here is the real rule (A7).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local BiomeRegions = require(ReplicatedStorage.Shared.BiomeRegions)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Layout = require(script.Parent.World.Layout)
local Parts = require(script.Parent.World.Parts)
local Kit = require(script.Parent.World.BiomeKit)
local Gate = require(script.Parent.World.Builders.Gate)

local B = Config.Biome

export type BiomeInfo = {
	biome: BiomeData.Biome,
	cf: CFrame,
	model: Model,
	skeleton: Kit.Skeleton,
}

local Biomes = {}
Biomes.HubSpawn = CFrame.new(0, Config.World.GroundY + 4, -70)

local gates: { [string]: Model } = {}
local infos: { [string]: BiomeInfo } = {}
local lastBounce: { [Player]: number } = {}

function Biomes.isUnlocked(profile: Data.Profile, biomeId: string): boolean
	local b = BiomeData.ById[biomeId]
	return b ~= nil and (b.Cost == 0 or profile.biomesUnlocked[biomeId] == true)
end

-- Highest unlocked biome index (zombie scaling and house tier gating).
function Biomes.highestUnlocked(profile: Data.Profile): number
	local best = 1
	for _, b in BiomeData.List do
		if Biomes.isUnlocked(profile, b.Id) then
			best = math.max(best, b.Index)
		end
	end
	return best
end

function Biomes.gate(biomeId: string): Model?
	return gates[biomeId]
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

-- Released and owned. Unreleased biomes bounce everyone, owners included.
function Biomes.canEnter(profile: Data.Profile, biomeId: string): boolean
	local b = BiomeData.ById[biomeId]
	return b ~= nil and b.Released and Biomes.isUnlocked(profile, biomeId)
end

local function bounce(player: Player, biome: BiomeData.Biome)
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(Biomes.HubSpawn)
	local now = os.clock()
	if (lastBounce[player] or 0) + 2 < now then
		lastBounce[player] = now
		local why = if biome.Released then `Unlock it at its gate for {Format.money(biome.Cost)}.` else "It isn't open yet."
		Net.notify(player, `{biome.Name} is locked. {why}`, "warn")
	end
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
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "Gates"
	gateFolder.Parent = worldFolder
	local biomeFolder = Instance.new("Folder")
	biomeFolder.Name = "Biomes"
	biomeFolder.Parent = worldFolder

	local builders = script.Parent.World.Builders.Biomes
	for _, b in BiomeData.List do
		gates[b.Id] = Gate.build(b, Layout.gateCFrame(b.Index), gateFolder)
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

	Players.PlayerRemoving:Connect(function(player)
		lastBounce[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(B.EnforceSeconds)
			for _, player in Players:GetPlayers() do
				local session = Data.get(player)
				local root = Biomes.rootOf(player)
				if session and root then
					local id = Biomes.regionOf(root.Position)
					if id and not Biomes.canEnter(session.data, id) then
						bounce(player, BiomeData.ById[id])
					end
				end
			end
		end
	end)
end

return Biomes
