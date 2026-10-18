--!strict
-- Guardian danger warning: a pulsing red edge vignette, a banner naming the guardian, and the
-- alert sound. Driven only by the server's Danger event, which only the target receives.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local Danger = {}

function Danger.start()
	local gui = Ui.screen("Danger", Players.LocalPlayer:WaitForChild("PlayerGui"), 15)
	gui.IgnoreGuiInset = true
	gui.Enabled = false

	local edges: { Frame } = {}
	local function edge(name: string, size: UDim2, pos: UDim2, rotation: number)
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Ui.Danger
		f.Size = size
		f.Position = pos
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = rotation
		g.Transparency = NumberSequence.new(0.35, 1)
		g.Parent = f
		table.insert(edges, f)
	end
	edge("Top", UDim2.fromScale(1, 0.14), UDim2.fromScale(0, 0), 90)
	edge("Bottom", UDim2.fromScale(1, 0.14), UDim2.fromScale(0, 0.86), -90)
	edge("Left", UDim2.fromScale(0.1, 1), UDim2.fromScale(0, 0), 0)
	edge("Right", UDim2.fromScale(0.1, 1), UDim2.fromScale(0.9, 0), 180)

	local banner = Ui.panel("Banner", UDim2.fromOffset(420, 64), gui)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 80)
	banner.BackgroundColor3 = Color3.fromRGB(60, 10, 20)
	local title = Ui.label("Title", "", true, banner)
	title.Size = UDim2.new(1, -16, 0, 34)
	title.Position = UDim2.fromOffset(8, 4)
	title.TextColor3 = Ui.Danger
	local sub = Ui.label("Sub", "Run to the SAFE ZONE or out of the biome! Unbanked seeds are at risk.", false, banner)
	sub.Size = UDim2.new(1, -16, 0, 20)
	sub.Position = UDim2.fromOffset(8, 38)

	local sound = Instance.new("Sound")
	sound.Name = "GuardianAlert"
	sound.Volume = 0.8
	sound.Parent = SoundService

	local pulse: Tween? = nil
	State.remote("Danger").OnClientEvent:Connect(function(on: boolean, name: string?, soundId: string?)
		gui.Enabled = on
		if pulse then
			pulse:Cancel()
			pulse = nil
		end
		if not on then
			return
		end
		title.Text = `{name or "A guardian"} is chasing you!`
		if soundId then
			sound.SoundId = soundId
			sound:Play()
		end
		local info = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		for _, f in edges do
			f.BackgroundTransparency = 0
		end
		pulse = TweenService:Create(banner, info, { BackgroundTransparency = 0.5 })
		if pulse then
			pulse:Play()
		end
	end)
end

return Danger
