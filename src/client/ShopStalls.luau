--!strict
-- Hub market stalls (Trails Shop, Shovel Shop). Stepping onto a stall's circle opens its menu
-- once per entry; staying or walking off never reopens or closes it, the X closes it, and
-- only one shop is open at a time. The server re-checks ownership, money and stall range.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Trails = require(ReplicatedStorage.Shared.Trails)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)
local Effects = require(script.Parent.Effects)

local ShopStalls = {}

local player = Players.LocalPlayer

type Row = {
	key: string,
	name: string,
	price: number,
	stat: string,
	preview: (Frame) -> (),
	owned: (State.Snapshot) -> boolean,
	equipped: (State.Snapshot) -> boolean,
	buy: () -> (),
	equip: () -> (),
}

type ShopDef = {
	id: string,
	title: string,
	accent: Color3,
	stroke: Color3,
	rows: { Row },
	unequip: (() -> ())?,
	unequipVisible: ((State.Snapshot) -> boolean)?,
}

type Menu = { panel: Frame, refresh: (State.Snapshot) -> () }

local EQUIP = Color3.fromHex("#4E6E8E")
local ROW_BG = Color3.fromHex("#2A3A30")

local menus: { [string]: Menu } = {}

function ShopStalls.open(id: string)
	for key, m in menus do
		m.panel.Visible = key == id
	end
end

function ShopStalls.close(id: string)
	local m = menus[id]
	if m then
		m.panel.Visible = false
	end
end

local function sequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for i, c in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(points)
end

local function box(name: string, size: UDim2, pos: UDim2, color: Color3, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function trailPreview(def: Trails.Trail): (Frame) -> ()
	return function(slot)
		local swatch = box("Swatch", UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1), slot)
		Ui.corner(swatch, 10)
		local g = Instance.new("UIGradient")
		g.Color = sequence(def.Colors)
		g.Rotation = 20
		g.Parent = swatch
	end
end

local function shovelPreview(def: Upgrades.Shovel): (Frame) -> ()
	return function(slot)
		slot.BackgroundColor3 = Color3.fromHex("#16201A")
		slot.BackgroundTransparency = 0
		Ui.corner(slot, 10)
		box("Handle", UDim2.fromScale(0.12, 0.5), UDim2.fromScale(0.44, 0.08), Color3.fromRGB(139, 98, 60), slot)
		box("Collar", UDim2.fromScale(0.2, 0.08), UDim2.fromScale(0.4, 0.56), def.Accent, slot)
		local blade = box("Blade", UDim2.fromScale(0.44, 0.3), UDim2.fromScale(0.28, 0.63), def.Color, slot)
		Ui.corner(blade, 8)
	end
end

local function buildMenu(def: ShopDef, playerGui: Instance): Menu
	local gui = Ui.screen(`{def.id}Shop`, playerGui, 6)
	local panel = Ui.panel("Panel", UDim2.new(0, 470, 0.86, 0), gui)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Visible = false
	panel.ClipsDescendants = true
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(470, 600)
	limit.Parent = panel
	local outline = panel:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Color = def.accent
		outline.Thickness = 3
	end

	local header = box("Header", UDim2.new(1, 0, 0, 60), UDim2.new(), def.accent, panel)
	Ui.corner(header)
	local title = Ui.label("Title", def.title, true, header)
	title.Size = UDim2.new(1, -200, 1, -12)
	title.Position = UDim2.fromOffset(16, 6)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = def.stroke
	titleStroke.Thickness = 2
	titleStroke.Parent = title

	local close = Ui.button("Close", "X", header)
	close.BackgroundColor3 = Ui.Danger
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Size = UDim2.fromOffset(48, 48)
	close.Position = UDim2.new(1, -6, 0.5, 0)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local unequip: TextButton? = nil
	if def.unequip then
		local b = Ui.button("Unequip", "Unequip", header)
		b.BackgroundColor3 = EQUIP
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Size = UDim2.fromOffset(112, Ui.MinTouch)
		b.Position = UDim2.new(1, -62, 0.5, 0)
		b.Visible = false
		b.Activated:Connect(def.unequip)
		unequip = b
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(10, 70)
	scroll.Size = UDim2.new(1, -20, 1, -80)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = def.accent
	scroll.Parent = panel
	Ui.list(scroll, Enum.FillDirection.Vertical, 8)

	local buttons: { [Row]: TextButton } = {}
	for i, row in def.rows do
		local r = box(`Row_{row.key}`, UDim2.new(1, -12, 0, 78), UDim2.new(), ROW_BG, scroll)
		r.LayoutOrder = i
		Ui.corner(r, 10)
		local slot = box("Preview", UDim2.fromOffset(60, 60), UDim2.fromOffset(9, 9), ROW_BG, r)
		slot.BackgroundTransparency = 1
		row.preview(slot)
		local name = Ui.label("Name", row.name, true, r)
		name.Size = UDim2.new(1, -212, 0, 32)
		name.Position = UDim2.fromOffset(80, 8)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local price = Ui.label("Price", if row.price == 0 then "FREE" else Format.money(row.price), false, r)
		price.Size = UDim2.new(0.5, -110, 0, 26)
		price.Position = UDim2.fromOffset(80, 44)
		price.TextXAlignment = Enum.TextXAlignment.Left
		price.TextColor3 = Ui.Warn
		local stat = Ui.label("Stat", row.stat, false, r)
		stat.Size = UDim2.new(0.5, -110, 0, 26)
		stat.Position = UDim2.new(0.5, -20, 0, 44)
		stat.TextXAlignment = Enum.TextXAlignment.Left
		local btn = Ui.button("Action", "Buy", r)
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Size = UDim2.fromOffset(118, Ui.MinTouch + 4)
		btn.Position = UDim2.new(1, -10, 0.5, 0)
		buttons[row] = btn
		btn.Activated:Connect(function()
			local snap = State.snapshot
			if not snap or row.equipped(snap) then
				return
			end
			if row.owned(snap) then
				row.equip()
				return
			end
			if snap.money < row.price then
				Notifications.show(`Not enough money. {row.name} costs {Format.money(row.price)}.`, "error")
				return
			end
			Ui.confirm(`Buy {row.name}?`, `{row.stat}. Equips right away.\nPrice: {Format.money(row.price)}`, `Buy {Format.money(row.price)}`, row.buy)
		end)
	end

	local function refresh(snap: State.Snapshot)
		for row, btn in buttons do
			if row.equipped(snap) then
				btn.Text = "Equipped"
				btn.BackgroundColor3 = Ui.Primary
				btn.AutoButtonColor = false
				btn.Active = false
			elseif row.owned(snap) then
				btn.Text = "Equip"
				btn.BackgroundColor3 = EQUIP
				btn.AutoButtonColor = true
				btn.Active = true
			else
				btn.Text = "Buy"
				btn.BackgroundColor3 = def.accent
				btn.AutoButtonColor = true
				btn.Active = true
			end
		end
		if unequip and def.unequipVisible then
			unequip.Visible = def.unequipVisible(snap)
		end
	end
	return { panel = panel, refresh = refresh }
end

local function trailShop(): ShopDef
	local rows: { Row } = {}
	for _, t in Trails.List do
		table.insert(rows, {
			key = t.Id, name = t.Name, price = t.Price, stat = `{t.Multiplier}x Speed`,
			preview = trailPreview(t),
			owned = function(s)
				return t.Price == 0 or s.trails.owned[t.Id] == true
			end,
			equipped = function(s)
				return s.trails.equipped == t.Id
			end,
			buy = function()
				State.remote("BuyTrail"):FireServer(t.Id)
			end,
			equip = function()
				State.remote("EquipTrail"):FireServer(t.Id)
			end,
		})
	end
	return {
		id = "Trails", title = "Trails Shop", accent = Color3.fromHex("#3BE23B"), stroke = Color3.fromHex("#0B3D0B"), rows = rows,
		unequip = function()
			State.remote("EquipTrail"):FireServer(Trails.DefaultId)
		end,
		unequipVisible = function(s)
			return s.trails.equipped ~= Trails.DefaultId
		end,
	}
end

local function shovelShop(): ShopDef
	local rows: { Row } = {}
	for _, sh in Upgrades.Shovels do
		local key = tostring(sh.Tier)
		table.insert(rows, {
			key = key, name = sh.Name, price = sh.Cost, stat = `Damage {sh.Damage}`,
			preview = shovelPreview(sh),
			owned = function(s)
				return sh.Cost == 0 or (s.shovels and s.shovels.owned[key] == true) or false
			end,
			equipped = function(s)
				return (if s.shovels then s.shovels.equipped else s.shovelTier) == sh.Tier
			end,
			buy = function()
				State.remote("BuyShovel"):FireServer(sh.Tier)
			end,
			equip = function()
				State.remote("EquipShovel"):FireServer(sh.Tier)
			end,
		})
	end
	return { id = "Shovels", title = "Shovel Shop", accent = Color3.fromHex("#2FB5FF"), stroke = Color3.fromHex("#0B2340"), rows = rows }
end

type Circle = { id: string, part: BasePart, inside: boolean }
local circles: { Circle } = {}

local function idle(part: BasePart)
	if Effects.reduced() then
		return
	end
	local bob = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local title = part:FindFirstChild("Title")
	if title and title:IsA("BillboardGui") then
		TweenService:Create(title, bob, { StudsOffsetWorldSpace = title.StudsOffsetWorldSpace + Vector3.new(0, 0.8, 0) }):Play()
	end
	TweenService:Create(part, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.65 }):Play()
end

local function track(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local id = inst:GetAttribute("ShopId")
	if type(id) ~= "string" or not menus[id] then
		return
	end
	table.insert(circles, { id = id, part = inst, inside = false })
	idle(inst)
end

function ShopStalls.start()
	local playerGui = player:WaitForChild("PlayerGui")
	for _, def in { trailShop(), shovelShop() } do
		menus[def.id] = buildMenu(def, playerGui)
	end
	State.onSnapshot(function(snap)
		for _, m in menus do
			m.refresh(snap)
		end
	end)

	task.spawn(function()
		local world = workspace:WaitForChild("World")
		for _, d in world:GetDescendants() do
			track(d)
		end
		world.DescendantAdded:Connect(track)
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				for _, c in circles do
					local radius = c.part:GetAttribute("Radius")
					local offset = root.Position - c.part.Position
					local inside = Vector3.new(offset.X, 0, offset.Z).Magnitude <= (if type(radius) == "number" then radius else 9)
					if inside and not c.inside then
						ShopStalls.open(c.id)
					end
					c.inside = inside
				end
			end
			task.wait(0.1)
		end
	end)
end

return ShopStalls
