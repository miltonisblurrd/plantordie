--!strict
-- Plant inspect popup. Reads the attributes the server set on the plant model.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Purchases = require(script.Parent.Purchases)

local Inspect = {}

local panel: Frame? = nil
local current: Model? = nil
local fields: { [string]: TextLabel } = {}
local growBtn: TextButton? = nil

local function close()
	current = nil
	if panel then
		panel.Visible = false
	end
end

local function refresh()
	local m = current
	if not m or not m.Parent then
		close()
		return
	end
	local def = Plants.ById[m:GetAttribute("Species") :: string]
	local rarity = Rarities.ById[m:GetAttribute("Rarity") :: string]
	fields.Name.Text = if def then def.Name else "?"
	fields.Name.TextColor3 = if rarity then rarity.Color else Ui.Text
	fields.Rarity.Text = `{rarity and rarity.Name or "?"} · {m:GetAttribute("Size")} · {m:GetAttribute("Variant")}`
	fields.Rarity.TextColor3 = if rarity then rarity.Color else Ui.Text
	local stage = m:GetAttribute("Stage") :: number
	local income = (m:GetAttribute("Income") :: number?) or 0
	if stage == 4 then
		fields.Status.Text = "Fully grown"
		fields.Income.Text = `Earning {Format.money(income)}/s`
	else
		local left = (m:GetAttribute("PlantedAt") :: number) + (m:GetAttribute("GrowSeconds") :: number) - os.time()
		fields.Status.Text = `{Economy.STAGES[stage]} · ready in {Format.clock(left)}`
		fields.Income.Text = `Will earn {Format.money(income)}/s`
	end
	if growBtn then
		local snap = State.snapshot
		local credits = if snap then snap.credits.InstantGrow or 0 else 0
		growBtn.Visible = stage ~= 4
		growBtn.Text = if credits > 0 then `Instant Grow (use x{credits})` else "Instant Grow (Robux)"
	end
	local combat = def and def.Combat
	fields.Role.Text = if combat and combat.Role ~= "Income"
		then `Defense: {combat.Role}{combat.Damage > 0 and ` · {combat.Damage} dmg` or ""}`
		else "Role: Income"
end

function Inspect.open(m: Model)
	local snap = State.snapshot
	if not panel or not snap or m:GetAttribute("PlotIndex") ~= snap.plotIndex then
		return
	end
	current = m
	panel.Visible = true
	refresh()
end

function Inspect.start()
	local gui = Ui.screen("Inspect", Players.LocalPlayer:WaitForChild("PlayerGui"), 5)
	local p = Ui.panel("Panel", UDim2.fromOffset(300, 314), gui)
	p.AnchorPoint = Vector2.new(1, 0.5)
	p.Position = UDim2.new(1, -12, 0.55, 0)
	p.Visible = false
	panel = p

	local y = 10
	local function line(name: string, h: number, title: boolean)
		local l = Ui.label(name, "", title, p)
		l.Size = UDim2.new(1, -24, 0, h)
		l.Position = UDim2.fromOffset(12, y)
		l.TextXAlignment = Enum.TextXAlignment.Left
		fields[name] = l
		y += h + 4
	end
	line("Name", 34, true)
	line("Rarity", 22, false)
	line("Status", 22, false)
	line("Income", 22, false)
	line("Role", 22, false)

	local grow = Ui.button("InstantGrow", "Instant Grow (Robux)", p)
	grow.BackgroundColor3 = Ui.Warn
	grow.Size = UDim2.new(1, -24, 0, Ui.MinTouch)
	grow.Position = UDim2.new(0, 12, 1, -(Ui.MinTouch * 2 + 20))
	grow.Visible = false
	growBtn = grow
	grow.Activated:Connect(function()
		local m = current
		local snap = State.snapshot
		if not m or not snap then
			return
		end
		local key = m:GetAttribute("TileKey") :: string
		if (snap.credits.InstantGrow or 0) > 0 then
			State.remote("UseCredit"):FireServer("InstantGrow", key)
		else
			Purchases.offer("InstantGrow", key)
		end
	end)

	local remove = Ui.button("Remove", "Dig Up", p)
	remove.BackgroundColor3 = Ui.Danger
	remove.Size = UDim2.new(0.5, -18, 0, Ui.MinTouch)
	remove.Position = UDim2.new(0, 12, 1, -(Ui.MinTouch + 12))
	remove.Activated:Connect(function()
		local m = current
		if not m then
			return
		end
		local key = m:GetAttribute("TileKey") :: string
		local grown = m:GetAttribute("Stage") == 4
		local body = if grown
			then "This plant moves to your plant inventory, keeping its size and variant. It stops earning until you place it again."
			elseif Config.Garden.UnripeSeedRefund > 0 then `It hasn't finished growing. Digging it up returns {Config.Garden.UnripeSeedRefund} seed.`
			else "It hasn't finished growing. Digging it up now destroys it and the seed is not returned."
		Ui.confirm("Dig up plant?", body, "Dig Up", function()
			State.remote("RemovePlant"):FireServer(key)
			close()
		end)
	end)
	local closeBtn = Ui.button("Close", "Close", p)
	closeBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 96)
	closeBtn.Size = UDim2.new(0.5, -18, 0, Ui.MinTouch)
	closeBtn.Position = UDim2.new(0.5, 6, 1, -(Ui.MinTouch + 12))
	closeBtn.Activated:Connect(close)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.25 and current then
			acc = 0
			refresh()
		end
	end)
end

return Inspect
