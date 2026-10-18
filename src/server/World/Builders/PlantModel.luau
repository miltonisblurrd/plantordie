--!strict
-- Builds a plant from its recipe for one growth stage (1 Seed, 2 Sprout, 3 Young, 4 Grown).
-- One stem, one head shape, one accent (brand.md). Size scales the grown plant, capped by
-- Sizes.VisualScale (max 1.8). `base` is the CFrame of the tile's top surface centre.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Plants = require(ReplicatedStorage.Shared.Plants)
local Sizes = require(ReplicatedStorage.Shared.Sizes)
local Parts = require(script.Parent.Parent.Parts)

export type Record = { species: string, size: string, variant: string }

local PlantModel = {}

local SOIL = Color3.fromRGB(96, 64, 40)

local function shapeOf(shape: string): (Enum.PartType?, boolean)
	if shape == "Wedge" then
		return nil, true
	elseif shape == "Ball" then
		return Enum.PartType.Ball, false
	elseif shape == "Cylinder" then
		return Enum.PartType.Cylinder, false
	end
	return Enum.PartType.Block, false
end

local function head(m: Model, recipe: Plants.ModelRecipe, cf: CFrame, size: number, neon: boolean): BasePart
	local shape, wedge = shapeOf(recipe.HeadShape)
	local dims = Vector3.new(size, size, size)
	local orient = CFrame.identity
	if recipe.HeadShape == "Cylinder" then
		dims = Vector3.new(size * 0.6, size * 1.2, size * 1.2)
		orient = CFrame.Angles(0, 0, math.rad(90))
	end
	return Parts.make({
		Name = "Head", Parent = m, Color = recipe.HeadColor, Shape = shape, Wedge = wedge,
		Material = if neon then Enum.Material.Neon else nil, CanCollide = false,
		Size = dims, CFrame = cf * orient,
	})
end

local function accent(m: Model, recipe: Plants.ModelRecipe, headCf: CFrame, stemCf: CFrame, s: number)
	local c = recipe.AccentColor
	local hs = recipe.HeadSize * s
	if recipe.Accent == "Petals" then
		for i = 0, 3 do
			local a = math.rad(i * 90 + 45)
			Parts.make({
				Name = "Petal", Parent = m, Color = c, CanCollide = false,
				Size = Vector3.new(hs * 0.55, hs * 0.18, hs * 0.55),
				CFrame = headCf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -hs * 0.55),
			})
		end
	elseif recipe.Accent == "Leaves" then
		for _, side in { -1, 1 } do
			Parts.make({
				Name = "Leaf", Parent = m, Color = c, CanCollide = false,
				Size = Vector3.new(1.4 * s, 0.25 * s, 0.8 * s),
				CFrame = stemCf * CFrame.new(side * 0.9 * s, 0, 0) * CFrame.Angles(0, 0, math.rad(side * 25)),
			})
		end
	elseif recipe.Accent == "Spikes" then
		for i = 0, 3 do
			Parts.make({
				Name = "Spike", Parent = m, Color = c, CanCollide = false, Wedge = true,
				Size = Vector3.new(0.3 * s, 0.8 * s, 0.6 * s),
				CFrame = headCf * CFrame.Angles(0, math.rad(i * 90), 0) * CFrame.new(hs * 0.25, hs * 0.5 + 0.4 * s, 0),
			})
		end
	elseif recipe.Accent == "Cap" then
		Parts.make({
			Name = "CapDot", Parent = m, Color = c, CanCollide = false, Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.6, 0.6, 0.6) * s,
			CFrame = headCf * CFrame.new(hs * 0.3, hs * 0.32, 0),
		})
	end
end

local function infoBillboard(m: Model, adornee: BasePart, height: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	bb.Adornee = adornee
	bb.Size = UDim2.fromOffset(120, 34)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Parent = m
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromHex("#1E2A22")
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = ""
	label.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
end

function PlantModel.build(record: Record, stage: number, base: CFrame, parent: Instance): Model
	local def = Plants.ById[record.species]
	local recipe = def.Model
	local variant = Plants.Variants[record.variant] or Plants.Variants.Normal
	local sizeDef = Sizes.ById[record.size]
	local s = math.min(sizeDef and sizeDef.VisualScale or 1, 1.8)

	local m = Instance.new("Model")
	m.Name = "Plant"

	local mound = Parts.make({
		Name = "Mound", Parent = m, Color = SOIL, CanCollide = false,
		Size = Vector3.new(2.6, 0.5, 2.6), CFrame = base * CFrame.new(0, 0.25, 0),
	})
	m.PrimaryPart = mound

	local top = 0.5
	if stage == 1 then
		Parts.make({
			Name = "Seed", Parent = m, Color = recipe.HeadColor:Lerp(SOIL, 0.5), Shape = Enum.PartType.Ball,
			CanCollide = false, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = base * CFrame.new(0, 0.7, 0),
		})
		top = 1.2
	else
		local growth = if stage == 2 then 0.3 elseif stage == 3 then 0.65 else 1
		local scale = if stage == 4 then s else 0.8
		local stemH = math.max(0.6, recipe.StemHeight * growth * scale)
		local stemW = 0.6 * scale
		local stemCf = base * CFrame.new(0, 0.5 + stemH / 2, 0)
		local stemShape = if recipe.StemShape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
		Parts.make({
			Name = "Stem", Parent = m, Color = recipe.StemColor, Shape = stemShape, CanCollide = false,
			Size = if stemShape == Enum.PartType.Cylinder
				then Vector3.new(stemH, stemW, stemW)
				else Vector3.new(stemW, stemH, stemW),
			CFrame = if stemShape == Enum.PartType.Cylinder then stemCf * CFrame.Angles(0, 0, math.rad(90)) else stemCf,
		})
		top = 0.5 + stemH
		if stage == 2 then
			for _, side in { -1, 1 } do
				Parts.make({
					Name = "Sprout", Parent = m, Color = Color3.fromRGB(90, 200, 90), CanCollide = false,
					Size = Vector3.new(0.9, 0.2, 0.5), CFrame = base * CFrame.new(side * 0.45, top, 0) * CFrame.Angles(0, 0, math.rad(side * 20)),
				})
			end
		else
			local hs = recipe.HeadSize * (if stage == 4 then s else 0.5)
			local headCf = base * CFrame.new(0, top + hs / 2, 0)
			local neon = stage == 4 and variant.Neon
			local h = head(m, recipe, headCf, hs, neon)
			top += hs
			if stage == 4 then
				accent(m, recipe, headCf, base * CFrame.new(0, 0.5 + stemH * 0.4, 0), s)
				if variant.Neon then
					local light = Instance.new("PointLight")
					light.Color = recipe.HeadColor
					light.Range = 10
					light.Brightness = 1.5
					light.Parent = h
					local particles = Instance.new("ParticleEmitter")
					particles.Rate = 3
					particles.Lifetime = NumberRange.new(1.5, 2.5)
					particles.Speed = NumberRange.new(0.5, 1)
					particles.Size = NumberSequence.new(0.25)
					particles.LightEmission = 1
					particles.Color = ColorSequence.new(recipe.HeadColor)
					particles.Parent = h
				end
				if variant.Rainbow then
					local sparkles = Instance.new("Sparkles")
					sparkles.Parent = h
					CollectionService:AddTag(m, "MegaPlant")
				end
			end
		end
	end

	infoBillboard(m, mound, top + 1.5)
	m.Parent = parent
	return m
end

return PlantModel
