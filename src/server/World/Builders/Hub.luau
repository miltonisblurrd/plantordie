--!strict
-- Central plaza: bright grass disc, stone ring for the gates, chunky trees, geometric rocks,
-- a fountain, a hub spawn, the Trails and Shovel market stalls, a world baseplate, and paths out to every plot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parent.Parts)
local Layout = require(script.Parent.Parent.Layout)
local Machine = require(script.Parent.Machine)

local W = Config.World

local Hub = {}

local function disc(name: string, radius: number, y: number, thickness: number, color: Color3, material: Enum.Material?, parent: Instance): BasePart
	return Parts.make({
		Name = name, Parent = parent, Color = color, Material = material,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(0, y - thickness / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
end

local WOOD = Color3.fromHex("#A86A32")

type StallLook = { title: string, stripeA: Color3, stripeB: Color3, circle: Color3, text: Color3, stroke: Color3 }

-- Axis-aligned so the harness bounding checks match the game; the open side faces the hub centre.
local function stall(id: string, at: Vector3, look: StallLook, parent: Instance): Model
	local m = Parts.model(`Stall_{id}`, parent)
	local f = if at.X < 0 then 1 else -1
	local base = Vector3.new(at.X, W.GroundY, at.Z)
	local function put(name: string, fwd: number, y: number, side: number, depth: number, h: number, width: number, color: Color3, collide: boolean?): BasePart
		return Parts.make({
			Name = name, Parent = m, Color = color, CanCollide = collide,
			Size = Vector3.new(depth, h, width), CFrame = CFrame.new(base + Vector3.new(fwd * f, y, side)),
		})
	end
	for _, c in { { -2.6, -4.6 }, { -2.6, 4.6 }, { 2.6, -4.6 }, { 2.6, 4.6 } } do
		put("Post", c[1], 3.6, c[2], 0.8, 7.2, 0.8, WOOD)
	end
	put("CounterTop", 2.2, 3.3, 0, 2.6, 0.6, 10.6, WOOD)
	put("CounterFront", 3.2, 1.5, 0, 0.5, 3, 10, WOOD)
	put("BackRail", -2.6, 2.2, 0, 0.5, 0.6, 9.2, WOOD)
	local stripes = 6
	local stripeW = 11.4 / stripes
	for i = 1, stripes do
		put("Canopy", 0, 7.5, -5.7 + stripeW * (i - 0.5), 7.6, 0.6, stripeW, if i % 2 == 1 then look.stripeA else look.stripeB, false)
	end

	local circle = Parts.make({
		Name = "ShopCircle", Parent = m, Color = look.circle, Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.4,
		Size = Vector3.new(0.2, Config.Shops.Radius * 2, Config.Shops.Radius * 2),
		CFrame = CFrame.new(base + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	circle.CanQuery = false
	circle.CanTouch = false
	circle.CastShadow = false
	circle:SetAttribute("ShopId", id)
	circle:SetAttribute("Radius", Config.Shops.Radius)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Title"
	gui.Size = UDim2.new(20, 0, 4.5, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	gui.Parent = circle
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = look.title
	label.TextColor3 = look.text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = look.stroke
	stroke.Thickness = 4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return m
end

function Hub.build(parent: Instance): Model
	local m = Parts.model("Hub", parent)

	local extent = Layout.mapExtent()
	Parts.make({
		Name = "Baseplate", Parent = m, Color = Color3.fromRGB(78, 176, 70), Material = Enum.Material.Grass,
		Size = Vector3.new(extent.X, 2, extent.Z + 120),
		CFrame = CFrame.new(0, W.GroundY - 1.2, extent.Z / 2 - 40),
	})
	disc("Plaza", W.HubRadius, W.GroundY + 0.2, 1, Color3.fromRGB(110, 222, 92), Enum.Material.Grass, m)

	-- Fountain centrepiece, behind the plot row.
	disc("FountainBase", 14, W.GroundY + 2.2, 2, Color3.fromRGB(170, 176, 186), nil, m)
	disc("FountainWater", 12, W.GroundY + 2.4, 0.4, Color3.fromRGB(90, 190, 255), Enum.Material.Neon, m)
	Parts.make({
		Name = "FountainPillar", Parent = m, Color = Color3.fromRGB(170, 176, 186),
		Size = Vector3.new(4, 8, 4), CFrame = CFrame.new(0, W.GroundY + 6, 0),
	})
	local title = Parts.make({
		Name = "TitleBoard", Parent = m, Color = Color3.fromHex("#1E2A22"),
		Size = Vector3.new(20, 5, 0.6), CFrame = CFrame.new(0, W.GroundY + 13, 0),
	})
	for _, name in { "Plaza", "FountainBase", "FountainWater", "FountainPillar", "TitleBoard" } do
		local part = m:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.CFrame = part.CFrame + Vector3.new(0, 0, -70)
		end
	end
	Parts.surfaceText(title, Enum.NormalId.Front, "PLANT OR DIE", Color3.fromHex("#3FBF4A"))
	Parts.surfaceText(title, Enum.NormalId.Back, "PLANT OR DIE", Color3.fromHex("#3FBF4A"))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, W.GroundY + 0.7, -70)
	spawn.Color = Color3.fromHex("#3FBF4A")
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = m

	-- One shared path from the plaza to the middle of the plot row.
	Parts.make({
		Name = "PlotPath", Parent = m, Color = Color3.fromRGB(196, 186, 168),
		Size = Vector3.new(14, 0.3, 36),
		CFrame = CFrame.new(0, W.GroundY + 0.05, -36),
	})

	-- One Neon maker and one Mega maker for the whole server.
	local Shared = require(script.Parent.Parent.SharedMachines)
	Shared.set("Neon", Machine.build("Neon", 0, CFrame.new(-22, W.GroundY, -70), m))
	Shared.set("Mega", Machine.build("Mega", 0, CFrame.new(22, W.GroundY, -70), m))
	for _, machine in Shared.all() do
		machine:SetAttribute("Shared", true)
	end

	stall("Trails", Config.Shops.Trails, {
		title = "Trails Shop", stripeA = Color3.fromHex("#3BE23B"), stripeB = Color3.fromHex("#FFFFFF"),
		circle = Color3.fromHex("#7CFF4F"), text = Color3.fromHex("#5CFF3A"), stroke = Color3.fromHex("#0B3D0B"),
	}, m)
	stall("Shovels", Config.Shops.Shovels, {
		title = "Shovel Shop", stripeA = Color3.fromHex("#2FB5FF"), stripeB = Color3.fromHex("#FFFFFF"),
		circle = Color3.fromHex("#3FD0FF"), text = Color3.fromHex("#3FD8FF"), stroke = Color3.fromHex("#0B2340"),
	}, m)

	local rng = Random.new(7)
	local leafColors = {
		Color3.fromRGB(46, 170, 70), Color3.fromRGB(80, 200, 90), Color3.fromRGB(30, 140, 80),
	}
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		local r = rng:NextNumber(18, 34)
		local cf = CFrame.new(math.cos(a) * r, W.GroundY + 0.2, -70 + math.sin(a) * r)
		if i % 3 == 0 then
			Parts.rock(cf, rng:NextNumber(0.8, 1.2), m)
		else
			Parts.tree(cf, rng:NextNumber(0.8, 1.1), leafColors[(i % #leafColors) + 1], m)
		end
	end

	return m
end

return Hub
