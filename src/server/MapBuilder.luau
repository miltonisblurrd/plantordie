local Config = require(game.ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.Name or "Part"
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Parent = props.Parent
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.CanCollide == false then
		p.CanCollide = false
	end
	return p
end

local function label(parent, text, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 36)
	gui.StudsOffset = offset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Text = text
	t.Parent = gui
	return t
end

function MapBuilder.build()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	part({
		Name = "Hub",
		Size = Vector3.new(90, 1, 90),
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(90, 180, 70),
		Material = Enum.Material.Grass,
		Parent = world,
	})
	local hubSign = part({
		Name = "HubSign",
		Size = Vector3.new(10, 6, 1),
		CFrame = CFrame.new(0, 4, -30),
		Color = Color3.fromRGB(255, 220, 80),
		Parent = world,
	})
	label(hubSign, "PLANT or DIE", Vector3.new(0, 0, 0))

	local meadow = part({
		Name = "RottingMeadow",
		Size = Vector3.new(160, 1, 140),
		CFrame = CFrame.new(0, 0, 180),
		Color = Color3.fromRGB(120, 150, 60),
		Material = Enum.Material.Grass,
		Parent = world,
	})
	meadow:SetAttribute("Biome", "RottingMeadow")
	local meadowSign = part({
		Name = "MeadowSign",
		Size = Vector3.new(14, 5, 1),
		CFrame = CFrame.new(0, 4, 116),
		Color = Color3.fromRGB(70, 90, 40),
		Parent = world,
	})
	label(meadowSign, "Rotting Meadow", Vector3.new(0, 0, 0), Color3.fromRGB(220, 255, 160))

	local portal = part({
		Name = "RaidPortal",
		Size = Vector3.new(10, 14, 1),
		CFrame = CFrame.new(50, 7, 220),
		Color = Color3.fromRGB(120, 40, 220),
		Material = Enum.Material.Neon,
		Parent = world,
	})
	label(portal, "Raid", Vector3.new(0, 2, 0), Color3.fromRGB(220, 180, 255))
	local raidPrompt = Instance.new("ProximityPrompt")
	raidPrompt.ActionText = "Start raid"
	raidPrompt.ObjectText = "Meadow raid"
	raidPrompt.Name = "RaidPrompt"
	raidPrompt.Parent = portal

	local function biomePad(name, title, center, color, monstersText)
		local pad = part({
			Name = name,
			Size = Vector3.new(140, 1, 120),
			CFrame = CFrame.new(center),
			Color = color,
			Material = Enum.Material.Grass,
			Parent = world,
		})
		local sign = part({
			Name = name .. "Sign",
			Size = Vector3.new(16, 5, 1),
			CFrame = CFrame.new(center + Vector3.new(0, 4, -54)),
			Color = Color3.fromRGB(30, 30, 40),
			Parent = world,
		})
		label(sign, title .. "\n" .. monstersText, Vector3.new(0, 1, 0))
		return pad
	end

	part({
		Name = "PathMeadow",
		Size = Vector3.new(14, 1, 70),
		CFrame = CFrame.new(0, 0.2, 95),
		Color = Color3.fromRGB(140, 120, 80),
		Material = Enum.Material.Slate,
		Parent = world,
	})
	part({
		Name = "PathHollow",
		Size = Vector3.new(120, 1, 14),
		CFrame = CFrame.new(150, 0.2, 180),
		Color = Color3.fromRGB(70, 40, 80),
		Material = Enum.Material.Slate,
		Parent = world,
	})
	part({
		Name = "PathCrater",
		Size = Vector3.new(120, 1, 14),
		CFrame = CFrame.new(-150, 0.2, 180),
		Color = Color3.fromRGB(30, 80, 80),
		Material = Enum.Material.Slate,
		Parent = world,
	})
	biomePad("VampireHollow", "Vampire Hollow", Vector3.new(280, 0, 180), Color3.fromRGB(50, 20, 60), "Needs 2 grown plants")
	biomePad("AlienCrater", "Alien Crater", Vector3.new(-280, 0, 180), Color3.fromRGB(20, 70, 70), "Needs 4 grown plants")
	local bossPortal = part({
		Name = "BossPortal",
		Size = Vector3.new(10, 14, 1),
		CFrame = CFrame.new(-250, 7, 220),
		Color = Color3.fromRGB(40, 220, 180),
		Material = Enum.Material.Neon,
		Parent = world,
	})
	label(bossPortal, "Boss rush", Vector3.new(0, 2, 0), Color3.fromRGB(180, 255, 230))
	local bossPrompt = Instance.new("ProximityPrompt")
	bossPrompt.ActionText = "Fight"
	bossPrompt.ObjectText = "Alien Queen and Rot King"
	bossPrompt.Name = "BossPrompt"
	bossPrompt.Parent = bossPortal
	local board = part({
		Name = "Leaderboard",
		Size = Vector3.new(14, 12, 1),
		CFrame = CFrame.new(30, 7, -20),
		Color = Color3.fromRGB(20, 24, 20),
		Parent = world,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Board"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(400, 360)
	surface.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.Text = "Top coins"
	title.Parent = surface
	local rows = Instance.new("TextLabel")
	rows.Name = "Rows"
	rows.Size = UDim2.new(1, -16, 1, -48)
	rows.Position = UDim2.new(0, 8, 0, 44)
	rows.BackgroundTransparency = 1
	rows.Font = Enum.Font.Gotham
	rows.TextSize = 22
	rows.TextXAlignment = Enum.TextXAlignment.Left
	rows.TextYAlignment = Enum.TextYAlignment.Top
	rows.TextColor3 = Color3.new(1, 1, 1)
	rows.Text = "Play to rank"
	rows.Parent = surface

	local tdPortal = part({
		Name = "DefensePortal",
		Size = Vector3.new(10, 14, 1),
		CFrame = CFrame.new(-30, 7, 20),
		Color = Color3.fromRGB(255, 140, 40),
		Material = Enum.Material.Neon,
		Parent = world,
	})
	label(tdPortal, "Tower defense", Vector3.new(0, 2, 0), Color3.fromRGB(255, 210, 140))
	local tdPrompt = Instance.new("ProximityPrompt")
	tdPrompt.ActionText = "Defend"
	tdPrompt.ObjectText = "Tower defense"
	tdPrompt.Name = "DefensePrompt"
	tdPrompt.Parent = tdPortal

	local raidArena = part({
		Name = "RaidArena",
		Size = Vector3.new(80, 1, 90),
		CFrame = CFrame.new(0, 0, 500),
		Color = Color3.fromRGB(40, 30, 50),
		Material = Enum.Material.Slate,
		Parent = world,
	})
	local raidCore = part({
		Name = "RaidCore",
		Size = Vector3.new(8, 10, 8),
		CFrame = CFrame.new(0, 5, 460),
		Color = Color3.fromRGB(180, 60, 255),
		Material = Enum.Material.Neon,
		Parent = world,
	})
	label(raidCore, "Protect the core", Vector3.new(0, 3, 0))

	local tdArena = part({
		Name = "DefenseArena",
		Size = Vector3.new(24, 1, 90),
		CFrame = CFrame.new(0, 0, -420),
		Color = Color3.fromRGB(50, 70, 40),
		Material = Enum.Material.Grass,
		Parent = world,
	})
	local tdHouse = part({
		Name = "DefenseHouse",
		Size = Vector3.new(14, 10, 10),
		CFrame = CFrame.new(0, 5, -470),
		Color = Color3.fromRGB(200, 170, 120),
		Parent = world,
	})
	label(tdHouse, "Hold the lane", Vector3.new(0, 3, 0))

	local plots = {}
	for i = 1, Config.PlotCount do
		local origin = CFrame.new(-150, 0, (i - 3.5) * 70)
		local folder = Instance.new("Folder")
		folder.Name = "Plot" .. i
		folder.Parent = world

		part({
			Name = "Pad",
			Size = Vector3.new(36, 1, 78),
			CFrame = origin * CFrame.new(0, 0, 10),
			Color = Color3.fromRGB(70, 140, 55),
			Material = Enum.Material.Grass,
			Parent = folder,
		})
		local house = part({
			Name = "House",
			Size = Vector3.new(16, 12, 14),
			CFrame = origin * CFrame.new(0, 6.5, -16),
			Color = Color3.fromRGB(230, 210, 170),
			Material = Enum.Material.Wood,
			Parent = folder,
		})
		local roof = part({
			Name = "Roof",
			Size = Vector3.new(18, 2, 16),
			CFrame = origin * CFrame.new(0, 13.5, -16),
			Color = Color3.fromRGB(170, 60, 50),
			Parent = folder,
		})
		part({
			Name = "Lane",
			Size = Vector3.new(10, 0.4, 62),
			CFrame = origin * CFrame.new(0, 0.4, 28),
			Color = Color3.fromRGB(90, 70, 45),
			Material = Enum.Material.Slate,
			Parent = folder,
		})
		local houseLabel = label(house, "Empty plot", Vector3.new(0, 8, 0))
		local hpLabel = label(house, "", Vector3.new(0, 6.2, 0), Color3.fromRGB(255, 180, 180))
		local barGui = Instance.new("BillboardGui")
		barGui.Size = UDim2.fromOffset(120, 10)
		barGui.StudsOffset = Vector3.new(0, 5, 0)
		barGui.AlwaysOnTop = true
		barGui.Parent = house
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = Color3.fromRGB(40, 16, 16)
		back.BorderSizePixel = 0
		back.Parent = barGui
		local hpFill = Instance.new("Frame")
		hpFill.Name = "Fill"
		hpFill.Size = UDim2.fromScale(1, 1)
		hpFill.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
		hpFill.BorderSizePixel = 0
		hpFill.Parent = back

		local spawn = origin * CFrame.new(0, 4, -2)
		local tiles = {}
		for t = 1, Config.TileCount do
			local tile = part({
				Name = "Tile" .. t,
				Size = Vector3.new(8, 1, 8),
				CFrame = origin * CFrame.new(0, 0.6, 6 + (t - 1) * 10),
				Color = Color3.fromRGB(110, 80, 50),
				Material = Enum.Material.Slate,
				Parent = folder,
			})
			tile:SetAttribute("Index", t)
			label(tile, tostring(t), Vector3.new(0, 2, 0), Color3.fromRGB(255, 230, 180))
			tiles[t] = tile
		end
		local monsterSpawn = (origin * CFrame.new(0, 3, 62)).Position

		plots[i] = {
			index = i,
			folder = folder,
			origin = origin,
			house = house,
			roof = roof,
			houseLabel = houseLabel,
			hpLabel = hpLabel,
			hpFill = hpFill,
			tiles = tiles,
			spawn = spawn,
			monsterSpawn = monsterSpawn,
			owner = nil,
		}
	end

	return {
		folder = world,
		meadow = meadow,
		plots = plots,
		meadowCenter = Vector3.new(0, 3, 180),
		raidPortal = portal,
		defensePortal = tdPortal,
		raidCore = raidCore,
		tdHouse = tdHouse,
		raidArena = raidArena,
		tdArena = tdArena,
		bossPortal = bossPortal,
		leaderboard = rows,
	}
end

return MapBuilder
