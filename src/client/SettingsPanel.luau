--!strict
-- Settings panel: music and SFX volume, camera mode, reduced effects.

local Players = game:GetService("Players")

local Ui = require(script.Parent.Ui)
local Settings = require(script.Parent.Settings)

local SettingsPanel = {}

local STEP = 0.1

local function volumeRow(p: Frame, y: number, label: string, key: string)
	local l = Ui.label(key .. "Label", label, false, p)
	l.Size = UDim2.new(0.4, -12, 0, Ui.MinTouch)
	l.Position = UDim2.fromOffset(12, y)
	l.TextXAlignment = Enum.TextXAlignment.Left
	local minus = Ui.button(key .. "Down", "-", p)
	minus.Size = UDim2.fromOffset(Ui.MinTouch, Ui.MinTouch)
	minus.Position = UDim2.new(0.4, 0, 0, y)
	local value = Ui.label(key .. "Value", "", false, p)
	value.Size = UDim2.new(0.6, -(Ui.MinTouch * 2 + 24), 0, Ui.MinTouch)
	value.Position = UDim2.new(0.4, Ui.MinTouch + 6, 0, y)
	local plus = Ui.button(key .. "Up", "+", p)
	plus.Size = UDim2.fromOffset(Ui.MinTouch, Ui.MinTouch)
	plus.Position = UDim2.new(1, -(Ui.MinTouch + 12), 0, y)
	local function nudge(d: number)
		local v = (Settings.values :: any)[key] :: number
		Settings.set(key, math.clamp(math.round((v + d) / STEP) * STEP, 0, 1))
	end
	minus.Activated:Connect(function()
		nudge(-STEP)
	end)
	plus.Activated:Connect(function()
		nudge(STEP)
	end)
	Settings.onChanged(function(v)
		value.Text = `{math.round(((v :: any)[key] :: number) * 100)}%`
	end)
end

local function toggleRow(p: Frame, y: number, key: string, render: (boolean) -> string)
	local b = Ui.button(key, "", p)
	b.Size = UDim2.new(1, -24, 0, Ui.MinTouch)
	b.Position = UDim2.fromOffset(12, y)
	b.Activated:Connect(function()
		Settings.set(key, not (Settings.values :: any)[key])
	end)
	Settings.onChanged(function(v)
		local on = (v :: any)[key] :: boolean
		b.Text = render(on)
		b.BackgroundColor3 = if on then Ui.Primary else Color3.fromRGB(90, 90, 96)
	end)
end

function SettingsPanel.start(bar: Instance)
	local gui = Ui.screen("Settings", Players.LocalPlayer:WaitForChild("PlayerGui"), 4)
	local p = Ui.panel("Panel", UDim2.fromOffset(360, 330), gui)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.5)
	p.Visible = false
	local title = Ui.label("Title", "Settings", true, p)
	title.Size = UDim2.new(1, -24, 0, 34)
	title.Position = UDim2.fromOffset(12, 8)
	volumeRow(p, 50, "Music", "music")
	volumeRow(p, 102, "Sound FX", "sfx")
	toggleRow(p, 160, "laneView", function(on)
		return if on then "Camera: Lane view on your plot" else "Camera: Follow"
	end)
	toggleRow(p, 212, "reducedEffects", function(on)
		return if on then "Reduced effects: ON" else "Reduced effects: OFF"
	end)
	local close = Ui.button("Close", "Close", p)
	close.BackgroundColor3 = Color3.fromRGB(90, 90, 96)
	close.Size = UDim2.new(1, -24, 0, Ui.MinTouch)
	close.Position = UDim2.new(0, 12, 1, -(Ui.MinTouch + 10))
	close.Activated:Connect(function()
		p.Visible = false
	end)

	local open = Ui.button("Settings", "Settings", bar)
	open.LayoutOrder = 9
	open.Size = UDim2.fromOffset(110, Ui.MinTouch + 4)
	open.Activated:Connect(function()
		p.Visible = not p.Visible
	end)
end

return SettingsPanel
