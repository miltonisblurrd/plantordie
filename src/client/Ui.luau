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

-- ScreenGui with safe-area insets and a UIScale that tracks the viewport (phones ~0.7, desktop 1).
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
	gui.Parent = playerGui
	return gui
end

return Ui
