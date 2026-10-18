--!strict
-- One biome gate arch with a sign and a collidable barrier. -Z of `cf` points away from the hub.
-- The barrier blocks everyone server-side; the client disables it locally for biomes the
-- player owns. The real rule is the server's biome region check (Biomes.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Format = require(ReplicatedStorage.Shared.Format)
local Parts = require(script.Parent.Parent.Parts)

local Gate = {}

local OPEN_W, H = 12, 14

function Gate.build(biome: Biomes.Biome, cf: CFrame, parent: Instance): Model
	local pal = biome.Palette
	local m = Parts.model("Gate_" .. biome.Id, parent)
	m:SetAttribute("BiomeIndex", biome.Index)
	m:SetAttribute("BiomeId", biome.Id)
	m:SetAttribute("Cost", biome.Cost)

	for _, side in { -1, 1 } do
		Parts.make({
			Name = "Pillar", Parent = m, Color = pal.Prop,
			Size = Vector3.new(3, H, 3), CFrame = cf * CFrame.new(side * (OPEN_W / 2 + 1.5), H / 2, 0),
		})
		Parts.make({
			Name = "PillarCap", Parent = m, Color = pal.Accent1,
			Size = Vector3.new(4, 1.5, 4), CFrame = cf * CFrame.new(side * (OPEN_W / 2 + 1.5), H + 0.75, 0),
		})
	end
	Parts.make({
		Name = "Beam", Parent = m, Color = pal.Ground,
		Size = Vector3.new(OPEN_W + 8, 2.5, 3), CFrame = cf * CFrame.new(0, H + 2.5, 0),
	})
	local board = Parts.make({
		Name = "SignBoard", Parent = m, Color = Color3.fromHex("#1E2A22"),
		Size = Vector3.new(OPEN_W + 6, 6, 0.6), CFrame = cf * CFrame.new(0, H + 6.75, 0.6),
	})
	local costText = if biome.Cost == 0 then "FREE" else Format.money(biome.Cost)
	-- Back (+Z) faces the hub.
	local title = Parts.surfaceText(board, Enum.NormalId.Back, `{biome.Name}\n{costText}`, pal.Accent1)
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.7)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0, 0.7)
	status.Size = UDim2.fromScale(1, 0.3)
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = if biome.Cost == 0 then Color3.fromHex("#3FBF4A") else Color3.fromRGB(255, 120, 120)
	status.Text = if biome.Cost == 0 then "UNLOCKED" else "LOCKED"
	status.Parent = title.Parent

	local barrier = Parts.make({
		Name = "Barrier", Parent = m, Color = pal.Accent1, Material = Enum.Material.Neon,
		Size = Vector3.new(OPEN_W, H, 1), CFrame = cf * CFrame.new(0, H / 2, 0),
		Transparency = 0.55, CanCollide = biome.Cost > 0,
	})
	barrier:SetAttribute("BiomeId", biome.Id)
	if biome.Cost == 0 then
		barrier.Transparency = 1
	else
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UnlockBiomePrompt"
		prompt.ActionText = `Unlock {Format.money(biome.Cost)}`
		prompt.ObjectText = biome.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("BiomeId", biome.Id)
		prompt.Parent = barrier
	end

	return m
end

return Gate
