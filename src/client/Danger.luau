--!strict
-- Chase effects, driven only by the server's Chase event (sent to the carrier alone):
--   start -> siren, a red full-screen flash, and a pulsing RUN! banner at top-centre that stays
--            until the chase ends. The biome banner is pushed below it via its YOffset attribute.
--   end   -> banner hidden (bank, catch, drop, safe area, timeout). A catch carries the
--            knockback impulse, applied here because the client owns its character's physics.
-- Also owns the DROP button, shown only while the snapshot says we carry a seed.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Sfx = require(script.Parent.Sfx)

local RED = Color3.fromHex("#E0242C")
local RED_DARK = Color3.fromHex("#9B0F16")
local STROKE = Color3.fromHex("#3A0004")
local FLASH = Color3.fromHex("#FF1E1E")
local DROP = Color3.fromHex("#FF5A1F")
local BANNER_Y = 8
local BIOME_Y_DEFAULT = 8
local BIOME_Y_CHASE = BANNER_Y + 70 + 26 + 8

local Danger = {}

local function stroked(label: TextLabel, px: number)
	local s = Instance.new("UIStroke")
	s.Thickness = px
	s.Color = STROKE
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = label
end

function Danger.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Ui.screen("Danger", playerGui, 15)
	gui.IgnoreGuiInset = true

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BorderSizePixel = 0
	flash.BackgroundColor3 = FLASH
	flash.BackgroundTransparency = 1
	flash.Size = UDim2.fromScale(1, 1)
	flash.Parent = gui

	local run = Instance.new("Frame")
	run.Name = "Run"
	run.AnchorPoint = Vector2.new(0.5, 0)
	run.Position = UDim2.new(0.5, 0, 0, BANNER_Y)
	run.Size = UDim2.new(0.6, 0, 0, 70)
	run.BackgroundTransparency = 1
	run.Visible = false
	run.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 70)
	limit.Parent = run
	local scale = Instance.new("UIScale")
	scale.Parent = run

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = RED
	bar.Size = UDim2.fromScale(1, 1)
	bar.ClipsDescendants = true
	bar.Parent = run
	Ui.corner(bar, 14)
	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BorderSizePixel = 0
	bottom.BackgroundColor3 = RED_DARK
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.fromScale(0, 1)
	bottom.Size = UDim2.new(1, 0, 0, 12)
	bottom.Parent = bar

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -16, 1, -14)
	title.Position = UDim2.fromOffset(8, 2)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "RUN!"
	title.ZIndex = 2
	title.Parent = bar
	stroked(title, 4)

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.new(0, 0, 1, 4)
	sub.Size = UDim2.new(1, 0, 0, 22)
	sub.Font = Enum.Font.GothamBlack
	sub.TextSize = 16
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.Text = ""
	sub.Parent = run
	stroked(sub, 2)

	local dropButton = Ui.button("Drop", "DROP", gui)
	dropButton.AnchorPoint = Vector2.new(0.5, 1)
	dropButton.Position = UDim2.new(0.5, 0, 1, -96)
	dropButton.Size = UDim2.fromOffset(150, 60)
	dropButton.BackgroundColor3 = DROP
	dropButton.TextColor3 = Color3.new(1, 1, 1)
	dropButton.Font = Enum.Font.FredokaOne
	dropButton.Visible = false
	local dropRemote = State.remote("DropSeed")
	dropButton.Activated:Connect(function()
		dropRemote:FireServer()
	end)
	State.onSnapshot(function(s)
		dropButton.Visible = s.carrying ~= nil
	end)

	local function biomeBanner(y: number)
		local bb = playerGui:FindFirstChild("BiomeBanner")
		local banner = bb and bb:FindFirstChild("Banner")
		if banner then
			banner:SetAttribute("YOffset", y)
		end
	end

	local pulse = TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.06 })
	local flashTween: Tween? = nil

	local function hide()
		pulse:Cancel()
		scale.Scale = 1
		run.Visible = false
		biomeBanner(BIOME_Y_DEFAULT)
	end

	State.remote("Chase").OnClientEvent:Connect(function(kind: string, name: string?, reason: string?, knockback: Vector3?)
		if kind == "start" then
			sub.Text = `{name or "A guardian"} is chasing you! Get to your plot!`
			Sfx.play("GuardianWarning")
			if flashTween then
				flashTween:Cancel()
			end
			flash.BackgroundTransparency = 0.55
			local t = TweenService:Create(flash, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
			flashTween = t
			t:Play()
			run.Visible = true
			biomeBanner(BIOME_Y_CHASE)
			scale.Scale = 1
			pulse:Play()
		elseif kind == "end" then
			hide()
			if reason == "catch" and typeof(knockback) == "Vector3" then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					root.AssemblyLinearVelocity = knockback
				end
			end
		end
	end)
end

return Danger
