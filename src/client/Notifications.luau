--!strict
-- Toast stack at top-centre. Server pushes via the Notify remote; client code may call show().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)
local Sfx = require(script.Parent.Sfx)

local Notifications = {}

local MAX_TOASTS = 4
local container: Frame? = nil

local KIND_COLORS: { [string]: Color3 } = {
	info = Ui.Primary,
	warn = Ui.Warn,
	error = Ui.Danger,
}

function Notifications.show(text: string, kind: string?, seconds: number?)
	if kind == "error" then
		Sfx.play("Error")
	end
	local root = container
	if not root then
		return
	end
	local toasts = {}
	for _, c in root:GetChildren() do
		if c:IsA("Frame") then
			table.insert(toasts, c)
		end
	end
	if #toasts >= MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	local toast = Ui.panel("Toast", UDim2.new(1, 0, 0, 48), root)
	toast.LayoutOrder = math.floor(os.clock() * 1000)
	local stroke = toast:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = KIND_COLORS[kind or "info"] or Ui.Primary
	end
	local label = Ui.label("Text", text, false, toast)
	label.Size = UDim2.new(1, -20, 1, -10)
	label.Position = UDim2.fromOffset(10, 5)
	toast.BackgroundTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = Ui.PanelTransparency }):Play()

	task.delay(seconds or 4, function()
		if toast.Parent then
			local t = TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
			t:Play()
			t.Completed:Wait()
			toast:Destroy()
		end
	end)
end

function Notifications.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Ui.screen("Notifications", playerGui, 10)
	local frame = Instance.new("Frame")
	frame.Name = "Toasts"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 70)
	frame.Size = UDim2.fromOffset(420, 240)
	frame.Parent = gui
	Ui.list(frame, Enum.FillDirection.Vertical, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	container = frame

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	remote.OnClientEvent:Connect(function(text: string, kind: string?)
		Notifications.show(text, kind)
	end)
end

return Notifications
