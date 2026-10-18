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

local panel: Frame? = nil
local list: ScrollingFrame? = nil

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

local function rebuild()
	local l = list
	local snap = State.snapshot
	if not l or not snap then
		return
	end
	for _, c in l:GetChildren() do
		if c:IsA("GuiButton") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
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
				l, order, `{def.Name} seed  x{n}`,
				`{def.Rarity} · from {Format.money(Economy.incomeOf(rec))}/s · {Format.clock(def.GrowSeconds)}`,
				rarity and rarity.Color or Ui.Text,
				function()
					Placement.select({ kind = "seed", id = def.Id })
					if panel then
						panel.Visible = false
					end
				end
			)
		end
	end
	for id, item in snap.plants do
		local def = Plants.ById[item.species]
		if def then
			any = true
			order += 1
			local rarity = Rarities.ById[item.rarity]
			local prefix = if item.variant ~= "Normal" then item.variant .. " " else ""
			entry(
				l, 1000 + order, `{prefix}{def.Name} ({item.size})`,
				`Grown plant · {Format.money(Economy.incomeOf(item))}/s · tap to place`,
				rarity and rarity.Color or Ui.Text,
				function()
					Placement.select({ kind = "plant", id = id })
					if panel then
						panel.Visible = false
					end
				end
			)
		end
	end
	if not any then
		local empty = Ui.label("Empty", "No seeds yet. Dig in biomes to find more!", false, l)
		empty.Size = UDim2.new(1, -8, 0, 40)
	end
end

function Inventory.toggle()
	if panel then
		panel.Visible = not panel.Visible
		if panel.Visible then
			rebuild()
		end
	end
end

function Inventory.start(bar: Frame)
	local gui = Ui.screen("Inventory", Players.LocalPlayer:WaitForChild("PlayerGui"), 4)
	local p = Ui.panel("Panel", UDim2.fromOffset(340, 360), gui)
	p.AnchorPoint = Vector2.new(0.5, 1)
	p.Position = UDim2.new(0.5, 0, 1, -76)
	p.Visible = false
	panel = p
	local title = Ui.label("Title", "Seeds & Plants", true, p)
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
	list = sf

	local open = Ui.button("Seeds", "Seeds", bar)
	open.LayoutOrder = 1
	open.Size = UDim2.fromOffset(110, Ui.MinTouch + 4)
	open.Activated:Connect(Inventory.toggle)

	State.onSnapshot(function()
		if p.Visible then
			rebuild()
		end
	end)
end

return Inventory
