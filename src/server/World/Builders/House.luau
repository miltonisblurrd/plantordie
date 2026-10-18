--!strict
-- Builds the house model for a tier. Plots swap models by calling build() with a new tier.
-- `base` is the CFrame of the house footprint centre on the ground, facing local +X toward the lanes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Houses = require(ReplicatedStorage.Shared.Houses)
local Parts = require(script.Parent.Parent.Parts)

local House = {}

function House.build(tier: number, base: CFrame, parent: Instance): Model
	local def = Houses.List[math.clamp(tier, 1, Houses.MaxTier)]
	local m = Parts.model("House", parent)
	m:SetAttribute("Tier", def.Tier)
	local s = def.Size

	local floor = Parts.make({
		Name = "Foundation", Parent = m, Color = def.TrimColor,
		Size = Vector3.new(s.X + 2, 1, s.Z + 2), CFrame = base * CFrame.new(0, 0.5, 0),
	})
	m.PrimaryPart = floor

	Parts.make({
		Name = "Walls", Parent = m, Color = def.WallColor,
		Size = Vector3.new(s.X, s.Y, s.Z), CFrame = base * CFrame.new(0, 1 + s.Y / 2, 0),
	})

	-- Gable roof from two wedges meeting along the X axis.
	local roofH = s.Y * 0.55
	local half = (s.Z + 2) / 2
	for _, side in { -1, 1 } do
		Parts.make({
			Name = "Roof", Parent = m, Color = def.RoofColor, Wedge = true,
			Size = Vector3.new(s.X + 2, roofH, half),
			CFrame = base
				* CFrame.new(0, 1 + s.Y + roofH / 2, side * half / 2)
				* CFrame.Angles(0, if side == 1 then math.pi else 0, 0),
		})
	end

	-- Door and windows face the lanes (+X).
	local faceX = s.X / 2 + 0.1
	Parts.make({
		Name = "Door", Parent = m, Color = def.TrimColor, CanCollide = false,
		Size = Vector3.new(0.4, 6, 4), CFrame = base * CFrame.new(faceX, 4, 0),
	})
	for _, z in { -s.Z / 3, s.Z / 3 } do
		Parts.make({
			Name = "Window", Parent = m, Color = Color3.fromRGB(160, 220, 255), CanCollide = false,
			Material = Enum.Material.Neon, Transparency = 0.2,
			Size = Vector3.new(0.4, 3, 3.5), CFrame = base * CFrame.new(faceX, 1 + s.Y * 0.6, z),
		})
	end

	for i = 1, def.Towers do
		local corner = ((i - 1) % 4)
		local x = if corner % 2 == 0 then -s.X / 2 else s.X / 2
		local z = if corner < 2 then -s.Z / 2 else s.Z / 2
		local h = s.Y + 6
		Parts.make({
			Name = "Tower", Parent = m, Color = def.TrimColor, Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, 5, 5), CFrame = base * CFrame.new(x, 1 + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		})
		Parts.make({
			Name = "TowerCap", Parent = m, Color = def.RoofColor,
			Size = Vector3.new(6, 2, 6), CFrame = base * CFrame.new(x, 2 + h, z),
		})
	end

	return m
end

return House
