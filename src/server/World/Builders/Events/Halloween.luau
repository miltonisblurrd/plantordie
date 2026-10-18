--!strict
-- Halloween hub decor (spec §12): pumpkins, spooky trees, a haunted shack (the seasonal shop),
-- lanterns, cobwebs, gravestones and a pumpkin patch dig spot. Built while the event is active
-- and destroyed when it ends. Kept to ~110 parts in the hub's south-east quarter.
-- Contract with the event manager: a part named "ShopCounter" holds the EventShopPrompt and a
-- part named "PumpkinPatch" holds the PumpkinDigPrompt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parent.Parent.Parts)

local Y = Config.World.GroundY + 0.7
local ORANGE = Color3.fromRGB(255, 117, 24)
local DARK = Color3.fromRGB(40, 30, 40)
local STONE = Color3.fromRGB(120, 120, 128)

local function pumpkin(cf: CFrame, s: number, parent: Instance)
	Parts.make({
		Name = "Pumpkin", Parent = parent, Color = ORANGE, Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 2.4, 3) * s, CFrame = cf * CFrame.new(0, 1.1 * s, 0),
	})
	Parts.make({
		Name = "PumpkinStem", Parent = parent, Color = Color3.fromRGB(70, 110, 40),
		Size = Vector3.new(0.4, 0.8, 0.4) * s, CFrame = cf * CFrame.new(0, 2.5 * s, 0),
	})
end

local function spookyTree(cf: CFrame, parent: Instance)
	Parts.make({
		Name = "SpookyTrunk", Parent = parent, Color = DARK,
		Size = Vector3.new(1.6, 12, 1.6), CFrame = cf * CFrame.new(0, 6, 0),
	})
	for i, off in { Vector3.new(2, 9, 0), Vector3.new(-2, 7.5, 0.5), Vector3.new(0.5, 11, -2) } do
		Parts.make({
			Name = "Branch" .. i, Parent = parent, Color = DARK,
			Size = Vector3.new(4, 0.6, 0.6), CFrame = cf * CFrame.new(off.X, off.Y, off.Z) * CFrame.Angles(0, i, math.rad(25)),
		})
	end
end

local function gravestone(cf: CFrame, parent: Instance)
	Parts.make({
		Name = "Gravestone", Parent = parent, Color = STONE,
		Size = Vector3.new(2.4, 3.2, 0.6), CFrame = cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(math.rad(-6), 0, 0),
	})
	Parts.make({
		Name = "GraveMound", Parent = parent, Color = Color3.fromRGB(90, 70, 50),
		Size = Vector3.new(2.6, 0.5, 4), CFrame = cf * CFrame.new(0, 0.25, 2.4),
	})
end

local function lantern(cf: CFrame, parent: Instance)
	Parts.make({
		Name = "LanternPost", Parent = parent, Color = DARK,
		Size = Vector3.new(0.5, 7, 0.5), CFrame = cf * CFrame.new(0, 3.5, 0),
	})
	local lamp = Parts.make({
		Name = "Lantern", Parent = parent, Color = Color3.fromRGB(255, 170, 60), Material = Enum.Material.Neon,
		Size = Vector3.new(1.2, 1.4, 1.2), CFrame = cf * CFrame.new(0, 7.4, 0), CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = lamp
end

local function cobweb(cf: CFrame, parent: Instance)
	for i = 0, 2 do
		Parts.make({
			Name = "Cobweb", Parent = parent, Color = Color3.fromRGB(235, 235, 240), Transparency = 0.45,
			CanCollide = false, Size = Vector3.new(0.1, 0.1, 4),
			CFrame = cf * CFrame.Angles(0, 0, math.rad(60 * i)),
		})
	end
end

local Halloween = {}

function Halloween.build(parent: Instance): Model
	local m = Parts.model("EventDecor_Halloween", parent)

	-- Haunted shack (seasonal shop), facing the fountain.
	local shack = CFrame.lookAt(Vector3.new(58, Y, 48), Vector3.new(0, Y, 0))
	Parts.make({ Name = "ShackFloor", Parent = m, Color = Color3.fromRGB(70, 50, 40), Size = Vector3.new(16, 0.6, 12), CFrame = shack * CFrame.new(0, 0.3, 0) })
	Parts.make({ Name = "ShackBack", Parent = m, Color = Color3.fromRGB(60, 45, 55), Size = Vector3.new(16, 10, 0.8), CFrame = shack * CFrame.new(0, 5, 5.6) })
	Parts.make({ Name = "ShackLeft", Parent = m, Color = Color3.fromRGB(60, 45, 55), Size = Vector3.new(0.8, 10, 12), CFrame = shack * CFrame.new(-7.6, 5, 0) })
	Parts.make({ Name = "ShackRight", Parent = m, Color = Color3.fromRGB(60, 45, 55), Size = Vector3.new(0.8, 10, 12), CFrame = shack * CFrame.new(7.6, 5, 0) })
	Parts.make({ Name = "ShackRoof", Parent = m, Color = Color3.fromRGB(35, 25, 35), Size = Vector3.new(18, 1, 14), CFrame = shack * CFrame.new(0, 10.4, 0) * CFrame.Angles(math.rad(-8), 0, 0) })
	local counter = Parts.make({
		Name = "ShopCounter", Parent = m, Color = Color3.fromRGB(90, 60, 45),
		Size = Vector3.new(10, 3.4, 2), CFrame = shack * CFrame.new(0, 1.7, -3),
	})
	local sign = Parts.make({
		Name = "ShopSign", Parent = m, Color = Color3.fromHex("#1E2A22"),
		Size = Vector3.new(12, 2.6, 0.4), CFrame = shack * CFrame.new(0, 8.4, -6.2),
	})
	Parts.surfaceText(sign, Enum.NormalId.Front, "SEASONAL SHOP", ORANGE)
	Parts.surfaceText(sign, Enum.NormalId.Back, "SEASONAL SHOP", ORANGE)
	cobweb(shack * CFrame.new(-7, 9.4, -5.6), m)
	cobweb(shack * CFrame.new(7, 9.4, -5.6), m)
	local shop = Instance.new("ProximityPrompt")
	shop.Name = "EventShopPrompt"
	shop.ActionText = "Seasonal Shop"
	shop.ObjectText = "Halloween"
	shop.HoldDuration = 0
	shop.MaxActivationDistance = 14
	shop.RequiresLineOfSight = false
	shop.Parent = counter

	-- Pumpkin patch dig spot.
	local patchCf = CFrame.new(32, Y, 66)
	local patch = Parts.make({
		Name = "PumpkinPatch", Parent = m, Color = Color3.fromRGB(95, 65, 40),
		Size = Vector3.new(12, 0.4, 12), CFrame = patchCf * CFrame.new(0, 0.2, 0),
	})
	for _, off in { Vector3.new(-3, 0, -3), Vector3.new(3, 0, -2), Vector3.new(-2, 0, 3), Vector3.new(3, 0, 3) } do
		pumpkin(patchCf * CFrame.new(off.X, 0.4, off.Z), 0.8, m)
	end
	local dig = Instance.new("ProximityPrompt")
	dig.Name = "PumpkinDigPrompt"
	dig.ActionText = "Dig for Candy"
	dig.ObjectText = "Pumpkin Patch"
	dig.HoldDuration = 1
	dig.MaxActivationDistance = Config.Event.DigRange
	dig.RequiresLineOfSight = false
	dig.Parent = patch

	-- Gravestones, trees, lanterns and loose pumpkins around the quarter.
	for i = 0, 5 do
		local a = math.rad(20 + i * 9)
		gravestone(CFrame.lookAt(Vector3.new(math.cos(a) * 78, Y, math.sin(a) * 78), Vector3.new(0, Y, 0)), m)
	end
	for i = 0, 4 do
		local a = math.rad(8 + i * 18)
		spookyTree(CFrame.new(math.cos(a) * 88, Y, math.sin(a) * 88), m)
	end
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		lantern(CFrame.new(math.cos(a) * 34, Y, math.sin(a) * 34), m)
	end
	for i = 0, 9 do
		local a = math.rad(i * 36 + 10)
		pumpkin(CFrame.new(math.cos(a) * 20, Y, math.sin(a) * 20), 0.7 + (i % 3) * 0.2, m)
	end
	return m
end

return Halloween
