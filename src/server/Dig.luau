--!strict
-- Dig spots and the Dig remote (spec §5). The client only names a spot; the server checks the
-- spot exists and is available, the player is close, owns the biome, holds a good enough
-- shovel and is off cooldown, then rolls the drop and puts it in the expedition bag (A6).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DropTables = require(ReplicatedStorage.Shared.DropTables)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Biomes = require(script.Parent.Biomes)
local Data = require(script.Parent.Data)
local Expedition = require(script.Parent.Expedition)
local Net = require(script.Parent.Net)

type Spot = {
	id: string,
	biomeId: string,
	position: Vector3,
	requiredTier: number,
	model: Model,
	availableAt: number,
	hp: number,
	maxHp: number,
}

local Dig = {}

local spots: { [string]: Spot } = {}
local lastDig: { [Player]: number } = {}
local rng = Random.new()

local function setAvailable(spot: Spot, available: boolean)
	spot.model:SetAttribute("Available", available)
	for _, d in spot.model:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("BaseTransparency") == nil then
				d:SetAttribute("BaseTransparency", d.Transparency)
			end
			d.Transparency = if available then d:GetAttribute("BaseTransparency") :: number else 1
			d.CanCollide = available and d.Name == "Body"
		elseif d:IsA("BillboardGui") then
			d.Enabled = available
		end
	end
end

local function handle(player: Player, spotId: string)
	local spot = spots[spotId]
	local session = Data.get(player)
	local character = player.Character
	local root = Biomes.rootOf(player)
	if not spot or not session or not character or not root then
		return
	end
	local now = os.clock()
	if spot.availableAt > now then
		return
	end
	if (root.Position - spot.position).Magnitude > Config.Dig.Range + 3 then
		return
	end
	if not Biomes.canEnter(session.data, spot.biomeId) or not Biomes.inRegion(spot.biomeId, root.Position) then
		return
	end
	if not character:FindFirstChild("Shovel") then
		Net.notify(player, "Equip your shovel to dig.", "warn")
		return
	end
	local shovel = Upgrades.Shovels[session.data.shovelTier] or Upgrades.Shovels[1]
	if (lastDig[player] or 0) + shovel.DigSeconds > now then
		return
	end
	lastDig[player] = now
	spot.hp -= shovel.Damage
	if spot.hp > 0 then
		Net.notify(player, `Dirt {math.ceil(spot.hp)}/{spot.maxHp}. A stronger shovel breaks it faster.`, "warn")
		return
	end

	local drop = DropTables.roll(spot.biomeId, shovel.LuckBonus, rng:NextNumber())
	if not drop or not Plants.ById[drop.Plant] then
		return
	end
	spot.availableAt = now + Config.Dig.RespawnSeconds
	setAvailable(spot, false)
	task.delay(Config.Dig.RespawnSeconds, function()
		spot.hp = spot.maxHp
		setAvailable(spot, true)
	end)
	if Expedition.add(player, drop.Plant, 1) then
		Net.fire("DigResult", player, spot.position, drop.Plant, drop.Rarity)
	end
end

function Dig.start()
	for _, biome in require(ReplicatedStorage.Shared.Biomes).List do
		local info = Biomes.info(biome.Id)
		if info then
			for _, s in info.skeleton.spots do
				local hp = biome.Index * Config.Biome.DirtHpPerIndex
				if s.requiredTier > 1 then
					hp = math.floor(hp * Config.Biome.ToughHpMultiplier)
				end
				spots[s.id] = {
					id = s.id, biomeId = biome.Id, position = s.cf.Position,
					requiredTier = s.requiredTier, model = s.model, availableAt = 0,
					hp = hp, maxHp = hp,
				}
			end
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastDig[player] = nil
	end)
	Net.on("Dig", { "string" }, handle)
end

function Dig.count(): number
	local n = 0
	for _ in spots do
		n += 1
	end
	return n
end

return Dig
