--!strict
-- Top-centre banner naming the biome the player stands in, with its recommended Speed.
-- Display-only. The top-centre slot above it is reserved: raise the Banner frame's
-- "YOffset" attribute to push it down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local BiomeRegions = require(ReplicatedStorage.Shared.BiomeRegions)
local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)

local POLL = 0.2
local HOLD = 0.3
local EDGE = 1
local STROKE = Color3.fromHex("#14141E")
local PILL = Color3.fromHex("#2F7BFF")

local BiomeBanner = {}

local function stroked(label: TextLabel, px: number)
	local s = Instance.new("UIStroke")
	s.Thickness = px
	s.Color = STROKE
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = label
end

local function text(name: string, font: Enum.Font, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = ""
	l.Parent = parent
	return l
end

function BiomeBanner.start()
	local player = Players.LocalPlayer
	local gui = Ui.screen("BiomeBanner", player:WaitForChild("PlayerGui"), 1)

	local banner = Instance.new("CanvasGroup")
	banner.Name = "Banner"
	banner.BackgroundTransparency = 1
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Size = UDim2.fromOffset(460, 84)
	banner.GroupTransparency = 1
	banner.Visible = false
	banner:SetAttribute("YOffset", 8)
	banner.Parent = gui
	local function place()
		local y = banner:GetAttribute("YOffset")
		banner.Position = UDim2.new(0.5, 0, 0, if type(y) == "number" then y else 8)
	end
	banner:GetAttributeChangedSignal("YOffset"):Connect(place)
	place()

	local pop = Instance.new("UIScale")
	pop.Parent = banner

	local title = text("Title", Enum.Font.FredokaOne, banner)
	title.Size = UDim2.new(1, 0, 0, 44)
	title.TextScaled = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 34
	cap.Parent = title
	stroked(title, 3)

	local line = Instance.new("Frame")
	line.Name = "Recommended"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(0, 48)
	line.Size = UDim2.new(1, 0, 0, 32)
	line.Parent = banner
	local row = Ui.list(line, Enum.FillDirection.Horizontal, 6)
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center

	local lead = text("Lead", Enum.Font.GothamBold, line)
	lead.LayoutOrder = 1
	lead.TextSize = 20
	lead.Text = "Recommended:"
	lead.AutomaticSize = Enum.AutomaticSize.X
	lead.Size = UDim2.fromOffset(0, 28)
	stroked(lead, 2)

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.LayoutOrder = 2
	pill.BackgroundColor3 = PILL
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 28)
	pill.Parent = line
	Ui.corner(pill, 14)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = pill
	local speed = text("Speed", Enum.Font.GothamBold, pill)
	speed.TextSize = 20
	speed.AutomaticSize = Enum.AutomaticSize.X
	speed.Size = UDim2.fromScale(0, 1)
	stroked(speed, 2)

	local fade = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local showTween = TweenService:Create(banner, fade, { GroupTransparency = 0 })
	local hideTween = TweenService:Create(banner, fade, { GroupTransparency = 1 })
	local popTween = TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	hideTween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			banner.Visible = false
		end
	end)

	local current: string? = nil
	local candidate: string? = nil
	local candidateSince = 0

	local function show(id: string)
		local b = BiomeData.ById[id]
		current = id
		candidate = nil
		title.Text = `{b.Emoji} {b.Name}`
		title.TextColor3 = b.Palette.Accent1
		speed.Text = `👟 {Format.speed(b.RecommendedSpeed)} Speed`
		hideTween:Cancel()
		banner.Visible = true
		showTween:Play()
		pop.Scale = 0.9
		popTween:Play()
	end

	local function hide()
		current = nil
		candidate = nil
		showTween:Cancel()
		hideTween:Play()
	end

	local function evaluate(immediate: boolean)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local id = if root and root:IsA("BasePart") then BiomeRegions.regionOf(root.Position) else nil
		if id == current then
			candidate = nil
			return
		end
		if id == nil then
			hide()
			return
		end
		local now = os.clock()
		if immediate or BiomeRegions.distanceInside(id, (root :: BasePart).Position) >= EDGE
			or (candidate == id and now - candidateSince >= HOLD) then
			show(id)
		elseif candidate ~= id then
			candidate = id
			candidateSince = now
		end
	end

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		evaluate(true)
	end)

	task.spawn(function()
		while true do
			evaluate(false)
			task.wait(POLL)
		end
	end)
end

return BiomeBanner
