--!strict
-- Lightweight lane zombie: 5-7 anchored, non-colliding parts. Pivot is at the feet and the
-- model faces its own -Z, so the service pivots it to face the house (-X on the plot).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zombies = require(ReplicatedStorage.Shared.Zombies)
local Parts = require(script.Parent.Parent.Parts)

local ZombieModel = {}

function ZombieModel.build(def: Zombies.Zombie, cf: CFrame, parent: Instance): Model
	local s = def.Scale
	local m = Instance.new("Model")
	m.Name = "Zombie"
	local function part(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): BasePart
		local p = Parts.make({
			Name = name, Parent = m, Color = color, CanCollide = false, Shape = shape,
			Size = size * s, CFrame = cf * CFrame.new(offset.Position * s) * offset.Rotation,
		})
		p.CastShadow = false
		return p
	end
	local root = part("Root", Vector3.new(2, 2.6, 1.2), CFrame.new(0, 2.3, 0), def.Color)
	local head = part("Head", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 4.4, 0), def.HeadColor, Enum.PartType.Ball)
	local eye = Color3.fromRGB(255, 30, 30)
	for _, side in { -0.35, 0.35 } do
		local e = part("Eye", Vector3.new(0.28, 0.28, 0.28), CFrame.new(side, 4.5, -0.7), eye, Enum.PartType.Ball)
		e.Material = Enum.Material.Neon
	end
	local glow = Instance.new("PointLight")
	glow.Color = eye
	glow.Range = 6
	glow.Brightness = 1.2
	glow.Parent = head
	part("ArmL", Vector3.new(0.45, 0.45, 2.2), CFrame.new(-0.9, 3.2, -1.3) * CFrame.Angles(math.rad(-70), 0, 0), def.HeadColor)
	part("ArmR", Vector3.new(0.45, 0.45, 2.2), CFrame.new(0.9, 3.2, -1.3) * CFrame.Angles(math.rad(-70), 0, 0), def.HeadColor)
	part("Legs", Vector3.new(1.6, 1, 1), CFrame.new(0, 0.5, 0), def.Color:Lerp(Color3.new(0, 0, 0), 0.4))
	if def.Id == "Bucket" then
		part("Bucket", Vector3.new(1.4, 1.2, 1.4), CFrame.new(0, 5.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(170, 175, 180), Enum.PartType.Cylinder)
	elseif def.Id == "Jumper" then
		part("Pole", Vector3.new(0.25, 0.25, 6), CFrame.new(1.1, 3, -1.5), Color3.fromRGB(150, 110, 70))
	elseif def.Id == "Spitter" then
		local sac = part("Sac", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 3.6, -0.9), Color3.fromRGB(160, 255, 60), Enum.PartType.Ball)
		sac.Material = Enum.Material.Neon
	elseif def.Id == "RotKing" then
		local crown = part("Crown", Vector3.new(1.8, 0.6, 1.8), CFrame.new(0, 5.4, 0), Color3.fromRGB(255, 200, 40))
		crown.Material = Enum.Material.Neon
	end
	m.PrimaryPart = root
	m.WorldPivot = cf
	m.Parent = parent
	return m
end

return ZombieModel
