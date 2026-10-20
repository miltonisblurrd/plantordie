--!strict
-- Treadmill presentation: "+96K 👟" popups above your belt on SpeedGain, and the upgrade sign's
-- prompts (money confirm -> UpgradeTreadmill; Robux -> Purchases). The server re-checks
-- ownership, level and price; non-owners get the server's notice.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local TreadmillData = require(ReplicatedStorage.Shared.Treadmill)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Settings = require(script.Parent.Settings)
local Notifications = require(script.Parent.Notifications)
local Purchases = require(script.Parent.Purchases)

local Treadmill = {}

local MAX_ALIVE = 3
local LIFETIME = 1.2
local RISE = 4
local BASE_HEIGHT = 5

local alive: { BillboardGui } = {}

local function ownBelt(): BasePart?
	local snap = State.snapshot
	if not snap or snap.plotIndex == 0 then
		return nil
	end
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild(`Plot_{snap.plotIndex}`)
	local model = plot and plot:FindFirstChild("Treadmill")
	local belt = model and model:FindFirstChild("Belt")
	return if belt and belt:IsA("BasePart") then belt else nil
end

local function remove(bb: BillboardGui)
	local i = table.find(alive, bb)
	if i then
		table.remove(alive, i)
	end
	bb:Destroy()
end

local function popup(amount: number, beltPosition: Vector3)
	local belt = ownBelt()
	if not belt then
		return
	end
	while #alive >= MAX_ALIVE do
		remove(alive[1])
	end
	local offset = beltPosition - belt.Position + Vector3.new((math.random() - 0.5) * 3, BASE_HEIGHT, (math.random() - 0.5) * 2)
	local bb = Instance.new("BillboardGui")
	bb.Name = "SpeedPopup"
	bb.Adornee = belt
	bb.Size = UDim2.fromOffset(220, 60)
	bb.StudsOffsetWorldSpace = offset
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Ui.Text
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = `+{Format.short(amount)} 👟`
	label.Parent = bb
	bb.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(alive, bb)
	if not Settings.values.reducedEffects then
		local info = TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(bb, info, { StudsOffsetWorldSpace = offset + Vector3.new(0, RISE, 0) }):Play()
		TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
	task.delay(LIFETIME, function()
		if bb.Parent then
			remove(bb)
		end
	end)
end

local function ownsSign(prompt: ProximityPrompt): boolean
	local snap = State.snapshot
	local board = prompt.Parent
	return snap ~= nil and board ~= nil and board:GetAttribute("PlotIndex") == snap.plotIndex
end

local function promptMoney()
	local snap = State.snapshot
	if not snap then
		return
	end
	local level = snap.treadmillLevel
	local cost = TreadmillData.nextCost(level)
	if not cost then
		Notifications.show("Your treadmill is already at max level.", "warn")
		return
	end
	if snap.money < cost then
		Notifications.show(`Not enough money. The next level costs {Format.money(cost)}.`, "error")
		return
	end
	local rate = TreadmillData.speedPerSec(level + 1)
	Ui.confirm(
		"Upgrade Treadmill?",
		`Lv. {level} > Lv. {level + 1}: earn {Format.short(rate)} speed per second on your belt.\nPrice: {Format.money(cost)}`,
		`Buy {Format.money(cost)}`,
		function()
			State.remote("UpgradeTreadmill"):FireServer()
		end
	)
end

function Treadmill.start()
	State.remote("SpeedGain").OnClientEvent:Connect(function(amount: number, beltPosition: Vector3, total: number?)
		if type(total) == "number" then
			State.setSpeed(total)
		end
		popup(amount, beltPosition)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name ~= "TreadmillMoneyPrompt" and prompt.Name ~= "TreadmillRobuxPrompt" then
			return
		end
		if not ownsSign(prompt) then
			return
		end
		if prompt.Name == "TreadmillMoneyPrompt" then
			promptMoney()
		elseif State.snapshot and TreadmillData.nextCost(State.snapshot.treadmillLevel) == nil then
			Notifications.show("Your treadmill is already at max level.", "warn")
		else
			Purchases.offer("TreadmillLevel")
		end
	end)
end

return Treadmill
