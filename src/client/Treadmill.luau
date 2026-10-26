--!strict
-- Treadmill presentation: "+96K 👟" popups above your belt on SpeedGain, and the upgrade sign's
-- prompts (money confirm -> UpgradeTreadmill; Robux -> a saved credit, else Purchases). At max
-- the server hides the R$ button and disables its prompt; this refuses too in case the sign lags.
-- The server re-checks ownership, level and price; non-owners get the server's notice.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local TreadmillData = require(ReplicatedStorage.Shared.Treadmill)
local Boosts = require(ReplicatedStorage.Shared.RobuxBoosts)
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

local RUN_ID = "rbxassetid://507767714"
local runTrack: AnimationTrack? = nil
local running = false

local function setRunning(on: boolean)
	if on == running then
		return
	end
	running = on
	local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator or not hum then
		running = false
		return
	end
	if on then
		local anim = Instance.new("Animation")
		anim.AnimationId = RUN_ID
		runTrack = animator:LoadAnimation(anim)
		runTrack.Priority = Enum.AnimationPriority.Action
		runTrack.Looped = true
		runTrack:Play(0.05)
	elseif runTrack then
		runTrack:Stop(0.15)
		runTrack = nil
	end
end

function Treadmill.start()
	local gui = Ui.screen("TreadmillUpgrade", Players.LocalPlayer:WaitForChild("PlayerGui"), 6)
	local upgradeBtn = Ui.button("Upgrade", "Upgrade treadmill", gui)
	upgradeBtn.AnchorPoint = Vector2.new(0.5, 1)
	upgradeBtn.Position = UDim2.new(0.5, 0, 1, -96)
	upgradeBtn.Size = UDim2.fromOffset(220, 44)
	upgradeBtn.Visible = false
	upgradeBtn.Activated:Connect(promptMoney)
	local speedBtn = Ui.button("SpeedRobux", "x1 SPEED", gui)
	speedBtn.AnchorPoint = Vector2.new(0.5, 1)
	speedBtn.Position = UDim2.new(0.5, 0, 1, -148)
	speedBtn.Size = UDim2.fromOffset(260, 52)
	speedBtn.BackgroundColor3 = Color3.fromRGB(255, 196, 40)
	speedBtn.Visible = false
	speedBtn.Activated:Connect(function()
		local snap = State.snapshot
		local nextTier = snap and Boosts.next("Speed", snap.speedRobuxTier or 0)
		if nextTier then
			Purchases.offer(nextTier.Key)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local belt = ownBelt()
		local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local on = false
		if belt and root and root:IsA("BasePart") then
			local rel = belt.CFrame:PointToObjectSpace(root.Position)
			local half = belt.Size / 2
			on = math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and rel.Y >= half.Y - 1 and rel.Y <= half.Y + 6
		end
		upgradeBtn.Visible = on
		local snap = State.snapshot
		local tier = if snap then snap.speedRobuxTier or 0 else 0
		local nowMult = Boosts.multiplier("Speed", tier)
		local nxt = Boosts.next("Speed", tier)
		speedBtn.Visible = on
		speedBtn.Text = if nxt then `⚡ x{nowMult} SPEED → x{nxt.Multiplier}\nONLY {nxt.Price} ROBUX` else `⚡ x{nowMult} SPEED  MAX`
		setRunning(on)
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		running = false
		runTrack = nil
	end)

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
		elseif State.snapshot and (State.snapshot.credits.TreadmillLevel or 0) > 0 then
			State.remote("UseCredit"):FireServer("TreadmillLevel")
		else
			Purchases.offer("TreadmillLevel")
		end
	end)
end

return Treadmill
