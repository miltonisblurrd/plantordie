--!strict
-- Main HUD. Renders only what State receives: money, income/sec, area, day/night countdown,
-- house HP, and an event slot. Layout keeps clear of the Roblox top bar and device safe area.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Format = require(game:GetService("ReplicatedStorage").Shared.Format)
local Rarities = require(game:GetService("ReplicatedStorage").Shared.Rarities)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local Hud = {}

local function timeOfDay(clockTime: number): string
	local minutes = math.floor((clockTime % 24) * 60)
	local h, m = minutes // 60, minutes % 60
	local h12 = if h % 12 == 0 then 12 else h % 12
	return string.format("%d:%02d %s", h12, m, if h < 12 then "AM" else "PM")
end

local function row(name: string, parent: Instance, order: number, height: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, height)
	f.LayoutOrder = order
	f.Parent = parent
	return f
end

local function padded(frame: Frame, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = frame
end

function Hud.start()
	local gui = Ui.screen("Hud", Players.LocalPlayer:WaitForChild("PlayerGui"), 1)

	-- Top-left: money, income and speed. Top-centre belongs to the biome banner.
	local money = Ui.panel("Money", UDim2.fromOffset(230, 108), gui)
	money.AnchorPoint = Vector2.new(0, 0)
	money.Position = UDim2.new(0, 12, 0, 12)
	padded(money, 8)
	Ui.list(money, Enum.FillDirection.Vertical, 2)
	local moneyText = Ui.label("Amount", "$0", true, row("AmountRow", money, 1, 40))
	moneyText.TextColor3 = Ui.Primary
	moneyText.TextXAlignment = Enum.TextXAlignment.Left
	local incomeText = Ui.label("Income", "+$0/s", false, row("IncomeRow", money, 2, 24))
	incomeText.TextXAlignment = Enum.TextXAlignment.Left
	local speedText = Ui.label("Speed", "👟 0 Speed", false, row("SpeedRow", money, 3, 22))
	speedText.TextColor3 = Color3.new(1, 1, 1)
	speedText.TextXAlignment = Enum.TextXAlignment.Left
	State.onSpeed(function(total)
		speedText.Text = `👟 {Format.short(total)} Speed`
	end)

	-- Top-right: day/night + countdown, area, event.
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.BackgroundTransparency = 1
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.new(1, -12, 0, 12)
	right.Size = UDim2.fromOffset(220, 200)
	right.Parent = gui
	Ui.list(right, Enum.FillDirection.Vertical, 6).HorizontalAlignment = Enum.HorizontalAlignment.Right

	local clock = Ui.panel("Clock", UDim2.fromOffset(220, 56), right)
	clock.LayoutOrder = 1
	padded(clock, 6)
	local clockText = Ui.label("Text", "DAY 0:00", true, clock)

	local area = Ui.panel("Area", UDim2.fromOffset(220, 44), right)
	area.LayoutOrder = 2
	padded(area, 6)
	local areaText = Ui.label("Text", "Hub", false, area)

	local event = Ui.panel("Event", UDim2.fromOffset(220, 44), right)
	event.LayoutOrder = 3
	event.Visible = false
	padded(event, 6)
	local eventText = Ui.label("Text", "", false, event)
	eventText.TextColor3 = Ui.Warn

	local carry = Ui.panel("Carrying", UDim2.fromOffset(220, 44), right)
	carry.LayoutOrder = 4
	carry.Visible = false
	padded(carry, 6)
	local carryText = Ui.label("Text", "", false, carry)

	-- Bottom-left: house HP.
	local house = Ui.panel("House", UDim2.fromOffset(260, 64), gui)
	house.AnchorPoint = Vector2.new(0, 1)
	house.Position = UDim2.new(0, 12, 1, -12)
	padded(house, 8)
	local houseName = Ui.label("Name", "Starter Shack", false, house)
	houseName.Size = UDim2.new(1, 0, 0, 20)
	houseName.TextXAlignment = Enum.TextXAlignment.Left
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromRGB(60, 30, 34)
	bar.BorderSizePixel = 0
	bar.Position = UDim2.fromOffset(0, 24)
	bar.Size = UDim2.new(1, 0, 0, 22)
	bar.Parent = house
	Ui.corner(bar, 8)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Ui.Primary
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bar
	Ui.corner(fill, 8)
	local hpText = Ui.label("Hp", "100 / 100", false, bar)
	hpText.ZIndex = 2

	State.onSnapshot(function(s)
		moneyText.Text = Format.money(s.money)
		incomeText.Text = `+{Format.money(s.incomePerSec)}/s`
		areaText.Text = s.area
		houseName.Text = s.houseName
		local frac = if s.houseMaxHp > 0 then math.clamp(s.houseHp / s.houseMaxHp, 0, 1) else 0
		fill.Size = UDim2.fromScale(frac, 1)
		fill.BackgroundColor3 = if frac > 0.5 then Ui.Primary elseif frac > 0.25 then Ui.Warn else Ui.Danger
		hpText.Text = `{math.floor(s.houseHp)} / {s.houseMaxHp}`
		event.Visible = s.event ~= nil
		local c = s.carrying
		carry.Visible = c ~= nil
		if c then
			local r = Rarities.ById[c.rarity]
			carryText.Text = `Carrying: {c.name}`
			carryText.TextColor3 = if r then r.Color else Ui.Warn
		end
	end)

	-- Countdown and event timer tick locally from server-provided end times.
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local dn = State.dayNight
		if dn then
			local left = math.max(0, dn.endsAt - workspace:GetServerTimeNow())
			local isNight = dn.phase == "Night"
			local tod = timeOfDay(Lighting.ClockTime)
			clockText.Text = if isNight
				then `NIGHT {dn.night}  {Format.clock(left)} · {tod}`
				else `DAY {Format.clock(left)} · {tod}`
			clockText.TextColor3 = if isNight then Color3.fromRGB(170, 160, 255) else Color3.fromRGB(255, 230, 120)
		end
		local snap = State.snapshot
		if snap and snap.event then
			local left = snap.event.endsAt - os.time()
			local days = left // 86400
			eventText.Text = if days >= 1
				then `{snap.event.name}: {days}d left`
				else `{snap.event.name}: {Format.clock(left % 86400 // 60)}h left`
		end
	end)
end

return Hud
