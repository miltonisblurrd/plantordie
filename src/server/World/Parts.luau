--!strict
-- Tiny part factory so builders stay declarative. Brand: SmoothPlastic/Neon/Grass, basic shapes only.

local Parts = {}

local made = 0

-- Parts created through this factory (world part budget, printed at boot).
function Parts.count(): number
	return made
end

export type Props = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Wedge: boolean?,
	CanCollide: boolean?,
	Transparency: number?,
	Parent: Instance,
}

function Parts.make(p: Props): BasePart
	local part: BasePart
	if p.Wedge then
		part = Instance.new("WedgePart")
	else
		local bp = Instance.new("Part")
		bp.Shape = p.Shape or Enum.PartType.Block
		part = bp
	end
	part.Name = p.Name or "Part"
	part.Anchored = true
	part.Size = p.Size
	part.CFrame = p.CFrame
	part.Color = p.Color
	part.Material = p.Material or Enum.Material.SmoothPlastic
	part.CanCollide = if p.CanCollide == nil then true else p.CanCollide
	part.Transparency = p.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = true
	part.Parent = p.Parent
	made += 1
	return part
end

function Parts.model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Face-mounted text sign. Returns the TextLabel so callers can update it.
function Parts.surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	return label
end

function Parts.tree(cf: CFrame, scale: number, leaf: Color3, parent: Instance): Model
	local m = Parts.model("Tree", parent)
	local trunkH = 8 * scale
	Parts.make({
		Name = "Trunk", Parent = m, Color = Color3.fromRGB(120, 80, 48),
		Size = Vector3.new(2.4 * scale, trunkH, 2.4 * scale),
		CFrame = cf * CFrame.new(0, trunkH / 2, 0),
	})
	Parts.make({
		Name = "Canopy", Parent = m, Color = leaf,
		Size = Vector3.new(9, 7, 9) * scale,
		CFrame = cf * CFrame.new(0, trunkH + 3 * scale, 0) * CFrame.Angles(0, math.rad(45), 0),
	})
	Parts.make({
		Name = "CanopyTop", Parent = m, Color = leaf:Lerp(Color3.new(1, 1, 1), 0.15),
		Size = Vector3.new(6, 4, 6) * scale,
		CFrame = cf * CFrame.new(0, trunkH + 8 * scale, 0),
	})
	return m
end

function Parts.rock(cf: CFrame, scale: number, parent: Instance): Model
	local m = Parts.model("Rock", parent)
	local grey = Color3.fromRGB(140, 146, 152)
	Parts.make({
		Name = "Base", Parent = m, Color = grey,
		Size = Vector3.new(6, 3.5, 5) * scale,
		CFrame = cf * CFrame.new(0, 1.5 * scale, 0) * CFrame.Angles(0, math.rad(20), math.rad(6)),
	})
	Parts.make({
		Name = "Chip", Parent = m, Color = grey:Lerp(Color3.new(1, 1, 1), 0.12), Wedge = true,
		Size = Vector3.new(4, 3, 4) * scale,
		CFrame = cf * CFrame.new(1 * scale, 4 * scale, 0) * CFrame.Angles(0, math.rad(-35), 0),
	})
	return m
end

return Parts
