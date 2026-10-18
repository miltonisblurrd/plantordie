--!strict
-- Seasonal shop for the active event (spec §12): countdown, currency, the full pack odds table
-- (every plant and its percent, summing to 100) shown before any purchase, buy with event
-- currency or the Robux product, and quests. Closes itself when the event ends.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Events)
local Format = require(ReplicatedStorage.Shared.Format)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)
local Purchases = require(script.Parent.Purchases)

local EventShop = {}

local panel: Frame? = nil
local ui: { [string]: any } = {}
local builtFor = ""

local function oddsText(e: Events.Event): string
	local lines = {}
	for _, o in Events.odds(e.Pack) do
		local def = Plants.ById[o.Plant]
		table.insert(lines, string.format("%s (%s)  %.1f%%", if def then def.Name else o.Plant, if def then def.Rarity else "?", o.Percent))
	end
	return table.concat(lines, "\n")
end

local function buildOdds(e: Events.Event)
	local list = ui.odds :: Frame
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local total = 0
	for i, o in Events.odds(e.Pack) do
		local def = Plants.ById[o.Plant]
		local rarity = def and Rarities.ById[def.Rarity]
		local row = Ui.label("Odds" .. i, string.format("%s · %s · %.1f%%", if def then def.Name else o.Plant, if def then def.Rarity else "?", o.Percent), false, list)
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 20)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if rarity then rarity.Color else Ui.Text
		total += o.Percent
	end
	local sum = Ui.label("Total", string.format("Total %.0f%%", total), false, list)
	sum.LayoutOrder = 100
	sum.Size = UDim2.new(1, 0, 0, 18)
	sum.TextXAlignment = Enum.TextXAlignment.Left
end

local function refresh()
	local p = panel
	local snap = State.snapshot
	if not p or not p.Visible then
		return
	end
	local info = snap and snap.event
	local e = info and Events.ById[info.id]
	if not info or not e then
		p.Visible = false
		Notifications.show("The event has ended. The shop is closed; your plants stay.", "info")
		return
	end
	if builtFor ~= e.Id then
		builtFor = e.Id
		ui.title.Text = `{e.Name} Shop`
		buildOdds(e)
	end
	ui.timer.Text = `Ends in {Format.duration(info.endsAt - State.now())}`
	ui.wallet.Text = `{info.currency}: {info.amount}  ·  dig the pumpkin patch (+{e.DigReward}) or survive nights (+{e.CurrencyPerNight})`
	ui.buyCurrency.Text = `Buy pack: {info.packCost} {info.currency}`
	ui.buyCurrency.BackgroundColor3 = if info.amount >= info.packCost then Ui.Primary else Color3.fromRGB(90, 90, 96)
	local quests = {}
	for _, q in info.quests do
		table.insert(quests, if q.done then `✓ {q.name} (+{q.reward})` else `{q.name}: {q.progress}/{q.goal} (+{q.reward})`)
	end
	ui.quests.Text = table.concat(quests, "\n")
end

local function confirmPack(viaRobux: boolean)
	local snap = State.snapshot
	local info = snap and snap.event
	local e = info and Events.ById[info.id]
	if not info or not e then
		Notifications.show("The event has ended.", "warn")
		return
	end
	if viaRobux then
		Purchases.offer(info.packProduct)
		return
	end
	if info.amount < info.packCost then
		Notifications.show(`Not enough {info.currency}. The pack costs {info.packCost}.`, "error")
		return
	end
	Ui.confirm(
		`Buy {info.packName}?`,
		`{e.Pack.Seeds} seed rolled from these odds:\n{oddsText(e)}\nPrice: {info.packCost} {info.currency}`,
		`Buy {info.packCost} {info.currency}`,
		function()
			State.remote("EventBuyPack"):FireServer(info.id)
		end
	)
end

function EventShop.toggle()
	local p = panel
	if not p then
		return
	end
	local snap = State.snapshot
	if not p.Visible and not (snap and snap.event) then
		Notifications.show("No event is running right now.", "info")
		return
	end
	p.Visible = not p.Visible
	refresh()
end

function EventShop.start(bar: GuiObject)
	local gui = Ui.screen("EventShop", Players.LocalPlayer:WaitForChild("PlayerGui"), 5)
	local p = Ui.panel("Panel", UDim2.fromOffset(420, 500), gui)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.48)
	p.Visible = false
	panel = p
	local y = 8
	local function line(name: string, h: number, title: boolean): TextLabel
		local l = Ui.label(name, "", title, p)
		l.Size = UDim2.new(1, -24, 0, h)
		l.Position = UDim2.fromOffset(12, y)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextWrapped = true
		y += h + 4
		return l
	end
	ui.title = line("Title", 34, true)
	ui.title.TextColor3 = Color3.fromRGB(255, 140, 40)
	ui.timer = line("Timer", 22, false)
	ui.timer.TextColor3 = Ui.Warn
	ui.wallet = line("Wallet", 40, false)
	line("OddsTitle", 22, true).Text = "Seed pack odds"
	local odds = Instance.new("Frame")
	odds.Name = "Odds"
	odds.BackgroundTransparency = 1
	odds.Size = UDim2.new(1, -24, 0, 170)
	odds.Position = UDim2.fromOffset(12, y)
	odds.Parent = p
	Ui.list(odds, Enum.FillDirection.Vertical, 2)
	ui.odds = odds
	y += 174
	local buyC = Ui.button("BuyCurrency", "Buy pack", p)
	buyC.Size = UDim2.new(0.5, -18, 0, Ui.MinTouch)
	buyC.Position = UDim2.fromOffset(12, y)
	buyC.Activated:Connect(function()
		confirmPack(false)
	end)
	ui.buyCurrency = buyC
	local buyR = Ui.button("BuyRobux", "Buy pack (Robux)", p)
	buyR.BackgroundColor3 = Ui.Warn
	buyR.Size = UDim2.new(0.5, -18, 0, Ui.MinTouch)
	buyR.Position = UDim2.new(0.5, 6, 0, y)
	buyR.Activated:Connect(function()
		confirmPack(true)
	end)
	y += Ui.MinTouch + 8
	ui.quests = line("Quests", 66, false)
	local close = Ui.button("Close", "Close", p)
	close.BackgroundColor3 = Color3.fromRGB(90, 90, 96)
	close.Size = UDim2.new(1, -24, 0, Ui.MinTouch)
	close.Position = UDim2.new(0, 12, 1, -(Ui.MinTouch + 10))
	close.Activated:Connect(function()
		p.Visible = false
	end)

	local open = Ui.button("Event", "Event", bar)
	open.LayoutOrder = 5
	open.BackgroundColor3 = Color3.fromRGB(255, 117, 24)
	open.Size = UDim2.fromOffset(100, Ui.MinTouch + 4)
	open.Visible = false
	open.Activated:Connect(EventShop.toggle)

	State.onSnapshot(function(s)
		open.Visible = s.event ~= nil
		refresh()
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "EventShopPrompt" then
			if not p.Visible then
				EventShop.toggle()
			end
		elseif prompt.Name == "PumpkinDigPrompt" then
			State.remote("EventDig"):FireServer()
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			refresh()
		end
	end)
end

return EventShop
