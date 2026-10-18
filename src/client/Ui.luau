--!strict
-- Brand-pinned UI primitives (brand.md): FredokaOne titles, GothamBold body, dark panel
-- #1E2A22 @ 0.15, 12 px corners, 2 px stroke, primary #3FBF4A, 44 px minimum touch targets.

local Ui = {}

Ui.Primary = Color3.fromHex("#3FBF4A")
Ui.Panel = Color3.fromHex("#1E2A22")
Ui.PanelTransparency = 0.15
Ui.Text = Color3.new(1, 1, 1)
Ui.Warn = Color3.fromHex("#FFB020")
Ui.Danger = Color3.fromHex("#FF4D6D")
Ui.MinTouch = 44

function Ui.corner(parent: GuiObject, px: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px or 12)
	c.Parent = parent
end

function Ui.stroke(parent: GuiObject, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = color or Ui.Primary
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

function Ui.panel(name: string, size: UDim2, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.BackgroundColor3 = Ui.Panel
	f.BackgroundTransparency = Ui.PanelTransparency
	f.BorderSizePixel = 0
	f.Parent = parent
	Ui.corner(f)
	Ui.stroke(f)
	return f
end

function Ui.label(name: string, text: string, title: boolean, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = if title then Enum.Font.FredokaOne else Enum.Font.GothamBold
	l.TextColor3 = Ui.Text
	l.TextScaled = true
	l.Text = text
	l.Size = UDim2.fromScale(1, 1)
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = if title then 30 else 20
	c.Parent = l
	return l
end

function Ui.button(name: string, text: string, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(120, Ui.MinTouch)
	b.BackgroundColor3 = Ui.Primary
	b.AutoButtonColor = true
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = Ui.Text
	b.TextScaled = true
	b.Text = text
	b.Parent = parent
	Ui.corner(b)
	Ui.stroke(b, Ui.Panel)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = b
	return b
end

function Ui.list(parent: Instance, direction: Enum.FillDirection, padPx: number): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction
	l.Padding = UDim.new(0, padPx)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

local confirmGui: ScreenGui? = nil

-- Modal confirm. `body` must state the exact benefit and price (brand.md).
function Ui.confirm(title: string, body: string, yesText: string, onYes: () -> ())
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	if confirmGui then
		confirmGui:Destroy()
	end
	local gui = Ui.screen("Confirm", playerGui, 20)
	confirmGui = gui
	local panel = Ui.panel("Dialog", UDim2.fromOffset(380, 210), gui)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	local t = Ui.label("Title", title, true, panel)
	t.Size = UDim2.new(1, -24, 0, 40)
	t.Position = UDim2.fromOffset(12, 10)
	local b = Ui.label("Body", body, false, panel)
	b.Size = UDim2.new(1, -24, 0, 90)
	b.Position = UDim2.fromOffset(12, 54)
	b.TextWrapped = true
	local close = function()
		gui:Destroy()
		if confirmGui == gui then
			confirmGui = nil
		end
	end
	local yes = Ui.button("Yes", yesText, panel)
	yes.Size = UDim2.new(0.5, -18, 0, Ui.MinTouch + 4)
	yes.Position = UDim2.new(0, 12, 1, -(Ui.MinTouch + 16))
	yes.Activated:Connect(function()
		close()
		onYes()
	end)
	local no = Ui.button("No", "Cancel", panel)
	no.BackgroundColor3 = Color3.fromRGB(90, 90, 96)
	no.Size = UDim2.new(0.5, -18, 0, Ui.MinTouch + 4)
	no.Position = UDim2.new(0.5, 6, 1, -(Ui.MinTouch + 16))
	no.Activated:Connect(close)
end

-- On touch screens the UIScale can shrink a 44 px button below 44 real pixels, so every
-- fixed-offset button is grown back to at least MinTouch after scaling.
local function enforceTouch(btn: GuiButton, scale: UIScale)
	local min = math.ceil(Ui.MinTouch / scale.Scale)
	local s = btn.Size
	local x = if s.X.Scale == 0 and s.X.Offset > 0 and s.X.Offset < min then min else s.X.Offset
	local y = if s.Y.Scale == 0 and s.Y.Offset > 0 and s.Y.Offset < min then min else s.Y.Offset
	if x ~= s.X.Offset or y ~= s.Y.Offset then
		btn.Size = UDim2.new(s.X.Scale, x, s.Y.Scale, y)
	end
end

local function watchTouch(gui: ScreenGui, scale: UIScale)
	local function hook(inst: Instance)
		if inst:IsA("GuiButton") then
			enforceTouch(inst, scale)
			inst:GetPropertyChangedSignal("Size"):Connect(function()
				enforceTouch(inst, scale)
			end)
		end
	end
	for _, d in gui:GetDescendants() do
		hook(d)
	end
	gui.DescendantAdded:Connect(hook)
	scale:GetPropertyChangedSignal("Scale"):Connect(function()
		for _, d in gui:GetDescendants() do
			if d:IsA("GuiButton") then
				enforceTouch(d, scale)
			end
		end
	end)
end

-- ScreenGui with safe-area insets (respects the top bar and notch) and a UIScale that tracks the
-- viewport (phones ~0.65, desktop 1).
function Ui.screen(name: string, playerGui: Instance, displayOrder: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 0
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local camera = workspace.CurrentCamera
	local function rescale()
		local v = camera.ViewportSize
		scale.Scale = math.clamp(math.min(v.X / 1280, v.Y / 720), 0.65, 1.25)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	if game:GetService("UserInputService").TouchEnabled then
		watchTouch(gui, scale)
	end
	gui.Parent = playerGui
	return gui
end

return Ui
