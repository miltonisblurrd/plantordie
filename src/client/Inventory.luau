--!strict
-- Seed and plant inventory panel. Selecting an entry hands it to Placement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Placement = require(script.Parent.Placement)

local Inventory = {}

local seedPanel: Frame? = nil
local plantPanel: Frame? = nil
local seedList: ScrollingFrame? = nil
local plantList: ScrollingFrame? = nil

local function entry(parent: Instance, order: number, title: string, sub: string, color: Color3, onPick: () -> ())
	local b = Ui.button("Entry", "", parent)
	b.LayoutOrder = order
	b.Size = UDim2.new(1, -8, 0, 56)
	b.BackgroundColor3 = Ui.Panel
	b.Text = ""
	local stroke = b:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	local t = Ui.label("Title", title, true, b)
	t.Size = UDim2.fromScale(1, 0.55)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = color
	local s = Ui.label("Sub", sub, false, b)
	s.Size = UDim2.fromScale(1, 0.45)
	s.Position = UDim2.fromScale(0, 0.55)
	s.TextXAlignment = Enum.TextXAlignment.Left
	b.Activated:Connect(onPick)
end

local function clearList(l: ScrollingFrame)
	for _, c in l:GetChildren() do
		if c:IsA("GuiButton") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
end

local function rebuild()
	local snap = State.snapshot
	if not snap then
		return
	end
	if seedList then
		clearList(seedList)
		local order = 0
		local any = false
		for _, def in Plants.List do
			local n = snap.seeds[def.Id] or 0
			if n > 0 then
				any = true
				order += 1
				local rarity = Rarities.ById[def.Rarity]
				local rec = { species = def.Id, rarity = def.Rarity, size = "Small", variant = "Normal" }
				entry(
					seedList, order, `{def.Name} seed  x{n}`,
					`{def.Rarity} · {Format.money(Economy.incomeOf(rec))}/s · {Format.clock(def.GrowSeconds)}`,
					rarity and rarity.Color or Ui.Text,
					function()
						Placement.select({ kind = "seed", id = def.Id })
						if seedPanel then
							seedPanel.Visible = false
						end
					end
				)
			end
		end
		if not any then
			local empty = Ui.label("Empty", "No seeds yet. Dig in biomes to find more!", false, seedList)
			empty.Size = UDim2.new(1, -8, 0, 40)
		end
	end
	if plantList then
		clearList(plantList)
		local order = 0
		local any = false
		for id, item in snap.plants do
			local def = Plants.ById[item.species]
			if def then
				any = true
				order += 1
				local rarity = Rarities.ById[item.rarity]
				local prefix = if item.variant ~= "Normal" then item.variant .. " " else ""
				entry(
					plantList, order, `{prefix}{def.Name} ({item.size})`,
					`Grown plant · {Format.money(Economy.incomeOf(item))}/s · tap to place`,
					rarity and rarity.Color or Ui.Text,
					function()
						Placement.select({ kind = "plant", id = id })
						if plantPanel then
							plantPanel.Visible = false
						end
					end
				)
			end
		end
		if not any then
			local empty = Ui.label("Empty", "No grown plants stored. Dig one up after it grows.", false, plantList)
			empty.Size = UDim2.new(1, -8, 0, 48)
		end
	end
end

local function makePanel(gui: Instance, name: string, titleText: string, anchorX: number, posX: number): (Frame, ScrollingFrame)
	local p = Ui.panel(name, UDim2.fromOffset(280, 380), gui)
	p.AnchorPoint = Vector2.new(anchorX, 0.5)
	p.Position = UDim2.new(posX, if anchorX == 0 then 156 else -156, 0.5, 0)
	p.Visible = false
	local title = Ui.label("Title", titleText, true, p)
	title.Size = UDim2.new(1, -24, 0, 34)
	title.Position = UDim2.fromOffset(12, 8)
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "List"
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Position = UDim2.fromOffset(10, 48)
	sf.Size = UDim2.new(1, -20, 1, -58)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.CanvasSize = UDim2.new()
	sf.ScrollBarThickness = 6
	sf.Parent = p
	Ui.list(sf, Enum.FillDirection.Vertical, 6)
	return p, sf
end

function Inventory.start(left: GuiObject, right: GuiObject)
	local gui = Ui.screen("Inventory", Players.LocalPlayer:WaitForChild("PlayerGui"), 4)
	local seeds, seedScroll = makePanel(gui, "Seeds", "Seeds", 0, 0)
	local plants, plantScroll = makePanel(gui, "Plants", "Plants", 1, 1)
	seedPanel, plantPanel = seeds, plants
	seedList, plantList = seedScroll, plantScroll

	local openSeeds = Ui.button("Seeds", "Seeds", left)
	openSeeds.LayoutOrder = 1
	openSeeds.Size = UDim2.fromOffset(120, Ui.MinTouch + 8)
	openSeeds.Activated:Connect(function()
		seeds.Visible = not seeds.Visible
		if seeds.Visible then
			rebuild()
		end
	end)
	local openPlants = Ui.button("Plants", "Plants", right)
	openPlants.LayoutOrder = 1
	openPlants.Size = UDim2.fromOffset(120, Ui.MinTouch + 8)
	openPlants.Activated:Connect(function()
		plants.Visible = not plants.Visible
		if plants.Visible then
			rebuild()
		end
	end)

	State.onSnapshot(function()
		if seeds.Visible or plants.Visible then
			rebuild()
		end
	end)
end

return Inventory
