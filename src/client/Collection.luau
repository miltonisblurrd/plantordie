--!strict
-- Collection index: every species by biome (event species last), discovered or "???", with
-- Normal / Neon / Mega badges from profile.collection ("species|variant").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Events = require(ReplicatedStorage.Shared.Events)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local Collection = {}

local BADGES = {
	{ Id = "Normal", Short = "N", Color = Color3.fromRGB(200, 200, 200) },
	{ Id = "Neon", Short = "NEON", Color = Color3.fromRGB(80, 255, 220) },
	{ Id = "Mega", Short = "MEGA", Color = Color3.fromRGB(255, 90, 220) },
}

local list: ScrollingFrame? = nil
local summary: TextLabel? = nil
local lastSig = ""

local function sections(): { { title: string, plants: { Plants.Plant } } }
	local out = {}
	for _, b in BiomeData.List do
		table.insert(out, { title = b.Name, plants = Plants.ByBiome[b.Id] or {} })
	end
	for _, e in Events.List do
		table.insert(out, { title = `{e.Name} (event)`, plants = Plants.ByBiome[e.Biome] or {} })
	end
	return out
end

local function rebuild()
	local l = list
	local snap = State.snapshot
	if not l or not snap then
		return
	end
	for _, c in l:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local found, total, order = 0, 0, 0
	for _, sec in sections() do
		order += 1
		local h = Ui.label("Section", sec.title, true, l)
		h.LayoutOrder = order
		h.Size = UDim2.new(1, -8, 0, 26)
		h.TextXAlignment = Enum.TextXAlignment.Left
		for _, def in sec.plants do
			order += 1
			total += 1
			local known = snap.collection[def.Id .. "|Normal"] or snap.collection[def.Id .. "|Neon"] or snap.collection[def.Id .. "|Mega"]
			if known then
				found += 1
			end
			local rarity = Rarities.ById[def.Rarity]
			local row = Instance.new("Frame")
			row.Name = "Row"
			row.LayoutOrder = order
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, -8, 0, 24)
			row.Parent = l
			local name = Ui.label("Name", if known then `{def.Name} · {def.Rarity}` else `??? · {def.Rarity}`, false, row)
			name.Size = UDim2.new(1, -150, 1, 0)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextColor3 = if known and rarity then rarity.Color else Color3.fromRGB(130, 130, 136)
			for i, b in BADGES do
				local has = snap.collection[def.Id .. "|" .. b.Id] == true
				local badge = Ui.label("Badge" .. b.Id, b.Short, true, row)
				badge.Size = UDim2.fromOffset(46, 20)
				badge.Position = UDim2.new(1, -150 + (i - 1) * 50, 0, 2)
				badge.BackgroundTransparency = if has then 0.2 else 0.85
				badge.BackgroundColor3 = b.Color
				badge.TextColor3 = if has then Color3.new(0, 0, 0) else Color3.fromRGB(120, 120, 126)
				Ui.corner(badge, 6)
			end
		end
	end
	if summary then
		summary.Text = `Discovered {found}/{total}`
	end
end

function Collection.start(bar: Frame)
	local gui = Ui.screen("Collection", Players.LocalPlayer:WaitForChild("PlayerGui"), 4)
	local p = Ui.panel("Panel", UDim2.fromOffset(420, 460), gui)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.48)
	p.Visible = false

	local title = Ui.label("Title", "Collection", true, p)
	title.Size = UDim2.new(0.5, -12, 0, 34)
	title.Position = UDim2.fromOffset(12, 8)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local sum = Ui.label("Summary", "", false, p)
	sum.Size = UDim2.new(0.5, -12, 0, 34)
	sum.Position = UDim2.new(0.5, 0, 0, 8)
	sum.TextXAlignment = Enum.TextXAlignment.Right
	summary = sum
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "List"
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Position = UDim2.fromOffset(10, 48)
	sf.Size = UDim2.new(1, -20, 1, -112)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.CanvasSize = UDim2.new()
	sf.ScrollBarThickness = 6
	sf.Parent = p
	Ui.list(sf, Enum.FillDirection.Vertical, 3)
	list = sf
	local close = Ui.button("Close", "Close", p)
	close.BackgroundColor3 = Color3.fromRGB(90, 90, 96)
	close.Size = UDim2.new(1, -24, 0, Ui.MinTouch)
	close.Position = UDim2.new(0, 12, 1, -(Ui.MinTouch + 10))
	close.Activated:Connect(function()
		p.Visible = false
	end)

	local open = Ui.button("Index", "Index", bar)
	open.LayoutOrder = 4
	open.Size = UDim2.fromOffset(100, Ui.MinTouch + 4)
	open.Activated:Connect(function()
		p.Visible = not p.Visible
		if p.Visible then
			lastSig = ""
			rebuild()
		end
	end)

	State.onSnapshot(function(s)
		if not p.Visible then
			return
		end
		local n = 0
		for _ in s.collection do
			n += 1
		end
		local sig = tostring(n)
		if sig ~= lastSig then
			lastSig = sig
			rebuild()
		end
	end)
end

return Collection
