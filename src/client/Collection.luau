--!strict
-- Collection index: every species grouped by biome (event species last). Each biome section shows
-- progress, its reward chips and a Claim button; discovered species show their head colour, name
-- and the variants found, locked ones a dark silhouette and "???". Data is the server's permanent
-- `collection`; completion and claiming are re-checked on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Discovery = require(ReplicatedStorage.Shared.Discovery)
local Events = require(ReplicatedStorage.Shared.Events)
local Format = require(ReplicatedStorage.Shared.Format)
local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local Collection = {}

local GOLD = Color3.fromHex("#FFC83D")
local BLUE = Color3.fromHex("#2F7BFF")
local SECRET = Color3.fromHex("#8E44AD")
local GREY = Color3.fromRGB(110, 110, 116)
local DARK = Color3.fromRGB(18, 18, 20)
local STROKE = Color3.fromRGB(20, 20, 24)

local BADGES: { [string]: { Short: string, Color: Color3 } } = {
	Neon = { Short = "Neon", Color = Color3.fromRGB(80, 255, 220) },
	Mega = { Short = "Mega", Color = Color3.fromRGB(255, 90, 220) },
}

type Section = { title: string, biome: BiomeData.Biome?, plants: { Plants.Plant } }

local list: ScrollingFrame? = nil
local summary: TextLabel? = nil
local lastSig = ""

local function sections(): { Section }
	local out: { Section } = {}
	for _, b in BiomeData.List do
		table.insert(out, { title = `{b.Emoji} {b.Name}`, biome = b, plants = Plants.ByBiome[b.Id] or {} })
	end
	for _, e in Events.List do
		table.insert(out, { title = `{e.Name} (event)`, plants = Plants.ByBiome[e.Biome] or {} })
	end
	return out
end

local function textStroke(l: TextLabel | TextButton)
	l.TextStrokeColor3 = STROKE
	l.TextStrokeTransparency = 0.2
end

local function chip(parent: Instance, name: string, text: string, color: Color3, order: number)
	local c = Ui.label(name, text, false, parent)
	c.LayoutOrder = order
	c.Size = UDim2.new(1 / 3, -4, 1, 0)
	c.BackgroundTransparency = 0.25
	c.BackgroundColor3 = color
	textStroke(c)
	Ui.corner(c, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = c
end

local function header(l: ScrollingFrame, sec: Section, order: number, snap: State.Snapshot): number
	local b = sec.biome
	order += 1
	local h = Ui.label("Section", sec.title, true, l)
	h.LayoutOrder = order
	h.Size = UDim2.new(1, -8, 0, 28)
	h.TextXAlignment = Enum.TextXAlignment.Left
	if not b then
		return order
	end
	h.TextColor3 = b.Palette.Accent1
	textStroke(h)

	local have, total = IndexRewards.progress(snap.collection, b.Id)
	local pct = if total > 0 then math.floor(have / total * 100) else 0
	order += 1
	local prog = Instance.new("Frame")
	prog.Name = "Progress"
	prog.LayoutOrder = order
	prog.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	prog.BorderSizePixel = 0
	prog.Size = UDim2.new(1, -8, 0, 22)
	prog.Parent = l
	Ui.corner(prog, 8)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Ui.Primary
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(if total > 0 then have / total else 0, 1)
	fill.Parent = prog
	Ui.corner(fill, 8)
	local pt = Ui.label("Text", `{have} / {total} plants · {pct}%`, false, prog)
	pt.ZIndex = 2
	textStroke(pt)

	local reward = IndexRewards.Rewards[b.Id]
	local skin = IndexRewards.SkinById[reward.Skin]
	order += 1
	local chips = Instance.new("Frame")
	chips.Name = "Rewards"
	chips.LayoutOrder = order
	chips.BackgroundTransparency = 1
	chips.Size = UDim2.new(1, -8, 0, 26)
	chips.Parent = l
	Ui.list(chips, Enum.FillDirection.Horizontal, 6)
	chip(chips, "Cash", `💰 {Format.money(reward.Cash)}`, GOLD, 1)
	chip(chips, "Speed", `👟 +{math.round(reward.SpeedBonus * 100)}% Speed forever`, BLUE, 2)
	chip(chips, "Skin", `🦇 {if skin then skin.Name else reward.Skin}`, if skin then skin.Primary else GREY, 3)

	local claimed = snap.indexClaimed[b.Id] == true
	local ready = not claimed and total > 0 and have >= total
	order += 1
	local btn = Ui.button("Claim", if claimed then "Claimed ✓" elseif ready then "Claim" else "Complete to claim", l)
	btn.LayoutOrder = order
	btn.Size = UDim2.new(1, -8, 0, Ui.MinTouch)
	btn.Active = ready
	btn.AutoButtonColor = ready
	btn.BackgroundColor3 = if ready then Ui.Primary else GREY
	btn.BackgroundTransparency = if ready or claimed then 0 else 0.4
	if ready then
		TweenService:Create(
			btn,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundColor3 = Color3.fromHex("#7BE384") }
		):Play()
		local biomeId = b.Id
		btn.Activated:Connect(function()
			State.remote("ClaimIndex"):FireServer(biomeId)
		end)
	end
	return order
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
		order = header(l, sec, order, snap)
		for _, def in sec.plants do
			order += 1
			total += 1
			local known = Discovery.best(snap.collection, def.Id) ~= nil
			if known then
				found += 1
			end
			local secret = IndexRewards.isSecret(def.Id)
			local rarity = Rarities.ById[def.Rarity]
			local rarityColor = if secret then SECRET elseif rarity then rarity.Color else Color3.new(1, 1, 1)
			local row = Instance.new("Frame")
			row.Name = "Row"
			row.LayoutOrder = order
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, -8, 0, 30)
			row.Parent = l
			local icon = Instance.new("Frame")
			icon.Name = "Icon"
			icon.Size = UDim2.fromOffset(26, 26)
			icon.Position = UDim2.fromOffset(0, 2)
			icon.BorderSizePixel = 0
			icon.BackgroundColor3 = if known then def.Model.HeadColor else DARK
			icon.Parent = row
			Ui.corner(icon, 13)
			local ring = Instance.new("UIStroke")
			ring.Thickness = 2
			ring.Color = rarityColor
			ring.Transparency = if known then 0 else 0.6
			ring.Parent = icon
			local name = Ui.label("Name", if known then def.Name else "???", false, row)
			name.Size = UDim2.new(1, -196, 1, 0)
			name.Position = UDim2.fromOffset(34, 0)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextColor3 = if known then Color3.new(1, 1, 1) else Color3.fromRGB(130, 130, 136)
			local rar = Ui.label("Rarity", if secret then "Secret" else def.Rarity, false, row)
			rar.Size = UDim2.fromOffset(70, 30)
			rar.Position = UDim2.new(1, -160, 0, 0)
			rar.TextColor3 = rarityColor
			for i, v in { "Neon", "Mega" } do
				local info = BADGES[v]
				local has = snap.collection[def.Id .. "|" .. v] == true
				local badge = Ui.label(v, info.Short, true, row)
				badge.Size = UDim2.fromOffset(42, 22)
				badge.Position = UDim2.new(1, -88 + (i - 1) * 46, 0, 4)
				badge.BackgroundTransparency = if has then 0.15 else 0.85
				badge.BackgroundColor3 = if has then info.Color else Color3.fromRGB(60, 60, 66)
				badge.TextColor3 = if has then Color3.new(0, 0, 0) else Color3.fromRGB(120, 120, 126)
				Ui.corner(badge, 6)
			end
		end
	end
	if summary then
		summary.Text = `Discovered {found}/{total}`
	end
end

local function signature(s: State.Snapshot): string
	local keys = {}
	for k in s.collection do
		table.insert(keys, k)
	end
	for k in s.indexClaimed do
		table.insert(keys, "!" .. k)
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

function Collection.start(bar: GuiObject)
	local gui = Ui.screen("Collection", Players.LocalPlayer:WaitForChild("PlayerGui"), 4)
	local p = Ui.panel("Panel", UDim2.fromScale(0.94, 0.86), gui)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.48)
	p.Visible = false
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(460, 560)
	cap.Parent = p

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
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.ScrollBarThickness = 8
	sf.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	sf.Parent = p
	Ui.list(sf, Enum.FillDirection.Vertical, 4)
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

	local prevClaimed: { [string]: boolean }? = nil
	State.onSnapshot(function(s)
		local before = prevClaimed
		prevClaimed = s.indexClaimed
		if before then
			for id in s.indexClaimed do
				if not before[id] then
					Sfx.play("WaveClear")
					break
				end
			end
		end
		if not p.Visible then
			return
		end
		local sig = signature(s)
		if sig ~= lastSig then
			lastSig = sig
			rebuild()
		end
	end)
end

return Collection
