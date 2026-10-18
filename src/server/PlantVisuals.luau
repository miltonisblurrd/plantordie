local PlantData = require(game.ReplicatedStorage.Shared.PlantData)
local Config = require(game.ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local ProfileUtil = require(script.Parent.ProfileUtil)

local PlantVisuals = {}
PlantVisuals.models = {}

local function makeModel(plant, def)
	local model = Instance.new("Model")
	model.Name = def.name
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3.2, 3.2, 3.2)
	body.Color = def.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Size = Vector3.new(0.6, 2, 0.6)
	stem.Color = Color3.fromRGB(40, 110, 40)
	stem.Anchored = true
	stem.CanCollide = false
	stem.Parent = model
	for index = 1, 3 do
		local leaf = Instance.new("Part")
		leaf.Name = "Leaf"
		leaf.Size = Vector3.new(1.4, 0.25, 0.7)
		leaf.Color = def.color
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.CFrame = body.CFrame * CFrame.new(math.cos(index * 2) * 1.2, 0.2, math.sin(index * 2) * 1.2)
		leaf.Parent = model
	end
	model.PrimaryPart = body
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 28)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body
	local text = Instance.new("TextLabel")
	text.Name = "Name"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextStrokeTransparency = 0.3
	text.TextColor3 = PlantData.RarityColor[def.rarity]
	text.Text = def.name
	text.Parent = gui
	model:SetAttribute("Uid", plant.uid)
	return model
end

function PlantVisuals.place(plant, cframe)
	PlantVisuals.clear(plant.uid)
	local def = PlantData.Plants[plant.id]
	if not def then
		return
	end
	local model = makeModel(plant, def)
	model.Parent = workspace:FindFirstChild("World")
	model:PivotTo(cframe)
	PlantVisuals.models[plant.uid] = model
	PlantVisuals.refresh(plant)
end

function PlantVisuals.clear(uid)
	local model = PlantVisuals.models[uid]
	if model then
		model:Destroy()
		PlantVisuals.models[uid] = nil
	end
end

function PlantVisuals.clearPlayer(player)
	local profile = State.profiles[player]
	if not profile then
		return
	end
	for _, plant in profile.plants do
		PlantVisuals.clear(plant.uid)
	end
end

function PlantVisuals.refresh(plant)
	local model = PlantVisuals.models[plant.uid]
	if not model then
		return
	end
	local body = model.PrimaryPart
	local def = PlantData.Plants[plant.id]
	local stunned = ProfileUtil.isStunned(plant)
	local growing = (plant.growLeft or 0) > 0
	body.Color = stunned and Color3.fromRGB(80, 80, 80) or (growing and Color3.fromRGB(120, 90, 50) or def.color)
	body.Size = growing and Vector3.new(1.6, 1.6, 1.6) or Vector3.new(3.2, 3.2, 3.2)
	local text = body:FindFirstChild("Name", true)
	if text and def then
		if stunned then
			local left = math.max(0, plant.stunnedUntil - os.time())
			text.Text = def.name .. " stunned " .. left .. "s"
		elseif growing then
			text.Text = def.name .. " growing " .. plant.growLeft .. "s"
		else
			text.Text = def.name
		end
	end
end

function PlantVisuals.sync(player)
	local profile = State.profiles[player]
	local plot = State.byPlayer[player]
	if not profile or not plot then
		return
	end
	local shown = {}
	for index, uid in profile.tiles do
		local tileIndex = tonumber(index)
		if tileIndex == 5 and profile.houseLevel < Config.FifthTileHouseLevel then
			continue
		end
		local plant = ProfileUtil.findPlant(profile, uid)
		local tile = plot.tiles[tileIndex]
		if plant and tile then
			shown[uid] = true
			if not PlantVisuals.models[uid] then
				PlantVisuals.place(plant, tile.CFrame * CFrame.new(0, 2.4, 0))
			else
				PlantVisuals.models[uid]:PivotTo(tile.CFrame * CFrame.new(0, 2.4, 0))
				PlantVisuals.refresh(plant)
			end
		end
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for i, uid in profile.followers do
		local plant = ProfileUtil.findPlant(profile, uid)
		if plant and root and not ProfileUtil.isStunned(plant) then
			shown[uid] = true
			local offset = CFrame.new(-4 + (i - 1) * 4, 1.5, 5)
			local cf = root.CFrame * offset
			if not PlantVisuals.models[uid] then
				PlantVisuals.place(plant, cf)
			else
				PlantVisuals.models[uid]:PivotTo(cf)
				PlantVisuals.refresh(plant)
			end
		end
	end
	for _, plant in profile.plants do
		if not shown[plant.uid] then
			PlantVisuals.clear(plant.uid)
		end
	end
end

return PlantVisuals
