--!strict
-- Elevated, angled view over your lanes while you stand on your own plot. Toggle with the
-- on-screen button, the C key, or Settings (camera mode). Falls back to the default follow camera everywhere else.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Settings = require(script.Parent.Settings)

local CameraController = {}

local OFFSET = Vector3.new(0, 70, -64) -- in plot space; -Z is the hub side

local enabled = true
local active = false
local button: TextButton? = nil

local function gardenFocus(plotIndex: number): (Vector3?, CFrame?)
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild(`Plot_{plotIndex}`) :: Model?
	local tiles = plot and plot:FindFirstChild("Tiles")
	if not plot or not tiles or not plot.PrimaryPart then
		return nil, nil
	end
	local sum, n = Vector3.zero, 0
	for _, t in tiles:GetChildren() do
		if t:IsA("BasePart") then
			sum += t.Position
			n += 1
		end
	end
	if n == 0 then
		return nil, nil
	end
	return sum / n, plot.PrimaryPart.CFrame
end

local function apply()
	local camera = workspace.CurrentCamera
	local snap = State.snapshot
	local want = enabled and snap ~= nil and snap.area == "Your Plot" and snap.plotIndex > 0
	if want and snap then
		local focus, plotCf = gardenFocus(snap.plotIndex)
		if not focus or not plotCf then
			return
		end
		local pos = focus + plotCf:VectorToWorldSpace(OFFSET)
		local target = CFrame.lookAt(pos, focus)
		camera.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(camera, TweenInfo.new(if active then 0.2 else 0.6, Enum.EasingStyle.Quad), { CFrame = target }):Play()
		active = true
	elseif active then
		active = false
		camera.CameraType = Enum.CameraType.Custom
		local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraSubject = hum
		end
	end
	if button then
		button.Text = if enabled then "Lane View: ON" else "Lane View: OFF"
		button.BackgroundColor3 = if enabled then Ui.Primary else Ui.Panel
	end
end

function CameraController.toggle()
	Settings.set("laneView", not enabled)
end

function CameraController.start()
	local gui = Ui.screen("CameraControls", Players.LocalPlayer:WaitForChild("PlayerGui"), 2)
	local b = Ui.button("LaneView", "Lane View: ON", gui)
	b.Size = UDim2.fromOffset(170, Ui.MinTouch)
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, -12, 1, -12)
	b.Activated:Connect(CameraController.toggle)
	button = b

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.C then
			CameraController.toggle()
		end
	end)
	Settings.onChanged(function(v)
		if v.laneView ~= enabled then
			enabled = v.laneView
			apply()
		end
	end)
	State.onSnapshot(function()
		apply()
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		active = false
		task.defer(apply)
	end)
end

return CameraController
