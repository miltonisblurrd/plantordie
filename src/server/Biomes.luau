--!strict
-- Builds the biome gates, all 15 biome areas and the trails between them; answers unlock and
-- region queries; and enforces locked regions on the server. Gate barriers are only a
-- client-side convenience: the region check here is the real rule (A7).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
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
Biomes.HubSpawn = CFrame.new(0, Config.World.GroundY + 4, 28)

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

local function inside(info: BiomeInfo, pos: Vector3): boolean
	local lp = info.cf:PointToObjectSpace(pos)
	local half = B.Size / 2 + 1
	return math.abs(lp.X) <= half and math.abs(lp.Z) <= half and lp.Y > -20 and lp.Y < 120
end

function Biomes.regionOf(pos: Vector3): string?
	local flat = Vector3.new(pos.X, 0, pos.Z).Magnitude
	if math.abs(flat - B.RingRadius) > B.Size * 0.75 then
		return nil
	end
	for id, info in infos do
		if inside(info, pos) then
			return id
		end
	end
	return nil
end

function Biomes.inRegion(biomeId: string, pos: Vector3): boolean
	local info = infos[biomeId]
	return info ~= nil and inside(info, pos)
end

function Biomes.inSafeZone(biomeId: string, pos: Vector3): boolean
	local info = infos[biomeId]
	if not info then
		return false
	end
	local d = Vector3.new(pos.X - info.skeleton.safeCenter.X, 0, pos.Z - info.skeleton.safeCenter.Z)
	return d.Magnitude <= info.skeleton.safeRadius
end

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

local function buildTrail(index: number, pal: BiomeData.Palette, parent: Instance)
	local pts = Layout.biomePath(index)
	local folder = Parts.model("Trail_" .. index, parent)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		Parts.make({
			Name = "TrailSegment", Parent = folder, Color = pal.Ground:Lerp(Color3.fromRGB(196, 186, 168), 0.6),
			Size = Vector3.new(B.PathWidth, 0.3, len + B.PathWidth),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.05, 0), b + Vector3.new(0, 0.05, 0)),
		})
	end
end

function Biomes.start(worldFolder: Instance)
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "Gates"
	gateFolder.Parent = worldFolder
	local biomeFolder = Instance.new("Folder")
	biomeFolder.Name = "Biomes"
	biomeFolder.Parent = worldFolder
	local trailFolder = Instance.new("Folder")
	trailFolder.Name = "Trails"
	trailFolder.Parent = worldFolder

	local builders = script.Parent.World.Builders.Biomes
	for _, b in BiomeData.List do
		gates[b.Id] = Gate.build(b, Layout.gateCFrame(b.Index), gateFolder)
		local cf = Layout.biomeCFrame(b.Index)
		local ctx = Kit.newCtx(b, cf, biomeFolder)
		local builderModule = builders:FindFirstChild(b.Id)
		assert(builderModule and builderModule:IsA("ModuleScript"), "Missing biome builder " .. b.Id)
		local build = (require :: any)(builderModule) :: (Kit.Ctx) -> ()
		build(ctx)
		infos[b.Id] = { biome = b, cf = cf, model = ctx.model, skeleton = Kit.skeleton(ctx) }
		buildTrail(b.Index, b.Palette, trailFolder)
	end

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
