--!strict
-- Tile targeting. With a seed/plant selected: hover (mouse) or tap (touch) shows a green/red
-- preview; click, or a second tap on the same tile, sends the request. With nothing selected,
-- clicking a plant opens Inspect. Client checks are only for feedback; the server decides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Plants = require(ReplicatedStorage.Shared.Plants)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)

export type Selection = { kind: "seed" | "plant", id: string }

local Placement = {}

local selection: Selection? = nil
local preview: Part? = nil
local hovered: BasePart? = nil
local selectionListeners: { (Selection?) -> () } = {}
local inspectHandler: ((Model) -> ())? = nil

local VALID = Color3.fromRGB(80, 255, 120)
local INVALID = Color3.fromRGB(255, 70, 90)

function Placement.onSelectionChanged(cb: (Selection?) -> ())
	table.insert(selectionListeners, cb)
end

function Placement.setInspectHandler(cb: (Model) -> ())
	inspectHandler = cb
end

function Placement.selection(): Selection?
	return selection
end

local function hidePreview()
	hovered = nil
	if preview then
		preview.Parent = nil
	end
end

function Placement.select(sel: Selection?)
	selection = sel
	if not sel then
		hidePreview()
	end
	for _, cb in selectionListeners do
		task.spawn(cb, sel)
	end
end

local function plotsFolder(): Instance?
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Plots")
end

-- Returns the tile under a screen point, and the plant model if a plant was hit.
local function tileAt(screen: Vector2, isTouch: boolean?): (BasePart?, Model?)
	local folder = plotsFolder()
	if not folder then
		return nil, nil
	end
	local camera = workspace.CurrentCamera
	-- Mouse positions are viewport space (include the top-bar inset); touch positions are screen space.
	local ray = if isTouch
		then camera:ScreenPointToRay(screen.X, screen.Y)
		else camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if not hit then
		return nil, nil
	end
	local inst: Instance? = hit.Instance
	local plant: Model? = nil
	while inst and inst ~= folder do
		if inst:IsA("Model") and inst:GetAttribute("TileKey") ~= nil and inst.Name:sub(1, 6) == "Plant_" then
			plant = inst
			break
		end
		if inst:IsA("BasePart") and inst:GetAttribute("TileKey") ~= nil then
			return inst, nil
		end
		inst = inst.Parent
	end
	if plant then
		local plot = plant.Parent and plant.Parent.Parent
		local tiles = plot and plot:FindFirstChild("Tiles")
		local tile = tiles and tiles:FindFirstChild("Tile_" .. tostring(plant:GetAttribute("TileKey")))
		return tile :: BasePart?, plant
	end
	return nil, nil
end

-- Mirrors the server checks for preview colour and friendly messages.
local function check(tile: BasePart): (boolean, string?)
	local snap = State.snapshot
	local sel = selection
	if not snap or not sel then
		return false, nil
	end
	if tile:GetAttribute("PlotIndex") ~= snap.plotIndex then
		return false, "You can only plant on your own plot."
	end
	local lane = tile:GetAttribute("Lane") :: number
	if lane > snap.lanesUnlocked then
		return false, `Lane {lane} is locked. Unlock it at the lane sign.`
	end
	if tile:GetAttribute("Occupied") then
		return false, "That tile already has a plant."
	end
	if snap.plantedCount >= snap.houseSlots then
		return false, "No free plant slots. Upgrade your house."
	end
	if sel.kind == "seed" and (snap.seeds[sel.id] or 0) < 1 then
		return false, "You're out of that seed."
	end
	if sel.kind == "plant" and not snap.plants[sel.id] then
		return false, "That plant is no longer in your inventory."
	end
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (root.Position - tile.Position).Magnitude > 60 then
		return false, "Get closer to your garden."
	end
	return true, nil
end

local function showPreview(tile: BasePart)
	local p = preview
	if not p then
		local np = Instance.new("Part")
		np.Name = "PlacementPreview"
		np.Anchored = true
		np.CanCollide = false
		np.CanQuery = false
		np.CanTouch = false
		np.Material = Enum.Material.Neon
		np.Transparency = 0.45
		preview = np
		p = np
	end
	assert(p, "preview part missing")
	local ok = check(tile)
	p.Color = if ok then VALID else INVALID
	p.Size = Vector3.new(tile.Size.X + 0.3, 0.3, tile.Size.Z + 0.3)
	p.CFrame = tile.CFrame * CFrame.new(0, tile.Size.Y / 2 + 0.2, 0)
	p.Parent = workspace
	hovered = tile
end

local function commit(tile: BasePart)
	local sel = selection
	if not sel then
		return
	end
	local ok, reason = check(tile)
	if not ok then
		Notifications.show(reason or "Can't plant there.", "error", 2.5)
		return
	end
	local key = tile:GetAttribute("TileKey") :: string
	if sel.kind == "seed" then
		State.remote("PlantSeed"):FireServer(key, sel.id)
		local snap = State.snapshot
		if snap and (snap.seeds[sel.id] or 0) <= 1 then
			Placement.select(nil)
		end
	else
		State.remote("PlacePlant"):FireServer(key, sel.id)
		Placement.select(nil)
	end
	hidePreview()
end

local function onPress(screen: Vector2, isTouch: boolean)
	local tile, plant = tileAt(screen, isTouch)
	if not selection then
		if plant and inspectHandler then
			inspectHandler(plant)
		elseif tile and tile:GetAttribute("Occupied") and inspectHandler then
			local folder = tile.Parent and tile.Parent.Parent
			local plants = folder and folder:FindFirstChild("Plants")
			local m = plants and plants:FindFirstChild("Plant_" .. tostring(tile:GetAttribute("TileKey")))
			if m and m:IsA("Model") then
				inspectHandler(m)
			end
		end
		return
	end
	if not tile then
		return
	end
	if isTouch and hovered ~= tile then
		showPreview(tile) -- first tap previews, second tap on the same tile plants
		return
	end
	commit(tile)
end

function Placement.start()
	local gui = Ui.screen("PlacementHint", Players.LocalPlayer:WaitForChild("PlayerGui"), 3)
	local hint = Ui.panel("Hint", UDim2.fromOffset(360, 48), gui)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -76)
	hint.Visible = false
	local hintText = Ui.label("Text", "", false, hint)
	hintText.Size = UDim2.new(1, -110, 1, -8)
	hintText.Position = UDim2.fromOffset(10, 4)
	local cancel = Ui.button("Cancel", "Cancel", hint)
	cancel.BackgroundColor3 = Color3.fromRGB(90, 90, 96)
	cancel.Size = UDim2.fromOffset(90, Ui.MinTouch)
	cancel.AnchorPoint = Vector2.new(1, 0.5)
	cancel.Position = UDim2.new(1, -2, 0.5, 0)
	cancel.Activated:Connect(function()
		Placement.select(nil)
	end)

	Placement.onSelectionChanged(function(sel)
		hint.Visible = sel ~= nil
		if sel then
			local name = sel.id
			local snap = State.snapshot
			if sel.kind == "seed" and Plants.ById[sel.id] then
				name = Plants.ById[sel.id].Name .. " seed"
			elseif sel.kind == "plant" and snap and snap.plants[sel.id] then
				local item = snap.plants[sel.id]
				name = `{item.variant ~= "Normal" and item.variant .. " " or ""}{Plants.ById[item.species] and Plants.ById[item.species].Name or item.species}`
			end
			hintText.Text = if UserInputService.TouchEnabled
				then `{name}: tap a tile, tap again to plant`
				else `{name}: click a soil tile`
		end
	end)

	UserInputService.InputChanged:Connect(function(input, processed)
		if processed or not selection or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local tile = tileAt(UserInputService:GetMouseLocation())
		if tile then
			showPreview(tile)
		else
			hidePreview()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onPress(UserInputService:GetMouseLocation(), false)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			onPress(Vector2.new(input.Position.X, input.Position.Y), true)
		elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Q then
			Placement.select(nil)
		end
	end)
end

return Placement
