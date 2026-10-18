--!strict
-- Part-built blocky guardian rigs. Every guardian shares a body plan (legs, torso, head, glowing
-- eyes) and its Shape adds a silhouette of its own. All parts are anchored and non-colliding;
-- the AI moves the whole model with PivotTo. The pivot sits at the feet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guardians = require(ReplicatedStorage.Shared.Guardians)
local Parts = require(script.Parent.Parent.Parts)

local GuardianRig = {}

local BALL = Enum.PartType.Ball
local NEON = Enum.Material.Neon

function GuardianRig.build(def: Guardians.Guardian, cf: CFrame, parent: Instance): Model
	local m = Parts.model("Guardian_" .. def.Biome, parent)
	m:SetAttribute("GuardianName", def.Name)
	local s = def.Scale
	local function add(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): BasePart
		local p = Parts.make({
			Name = name, Parent = m, Size = size * s, CFrame = cf * CFrame.new(offset.Position * s) * offset.Rotation,
			Color = color, Shape = shape, Material = material, CanCollide = false,
		})
		p.CanQuery = false
		p.CanTouch = false
		return p
	end

	local root = add("Root", Vector3.new(1, 1, 1), CFrame.new(), def.Body)
	root.Transparency = 1
	m.PrimaryPart = root

	local shape = def.Shape
	local legH = if shape == "Squat" or shape == "Crab" then 1.6 elseif shape == "Tall" then 4 else 3
	local torso = if shape == "Brute" or shape == "Golem" then Vector3.new(6, 5, 3.4)
		elseif shape == "Squat" then Vector3.new(5, 3, 4)
		elseif shape == "Crab" then Vector3.new(7, 2.4, 5)
		elseif shape == "Tall" then Vector3.new(2.6, 7, 2)
		elseif shape == "Scarecrow" then Vector3.new(2.4, 4.5, 1.6)
		else Vector3.new(4, 4, 2.4)
	local hover = if shape == "Floating" then 2.5 else 0

	if shape ~= "Floating" then
		local legs: { number } = if shape == "Crab" then { -2.6, -1, 1, 2.6 } else { -torso.X / 4, torso.X / 4 }
		for _, x in legs do
			add("Leg", Vector3.new(1.3, legH, 1.3), CFrame.new(x, legH / 2, 0), def.Trim)
		end
	end
	local torsoY = legH + hover + torso.Y / 2
	if shape == "Floating" then
		add("Torso", Vector3.one * 5, CFrame.new(0, torsoY, 0), def.Body, BALL)
		add("Tail", Vector3.new(2.4, 3, 2.4), CFrame.new(0, torsoY - 3, 0.6) * CFrame.Angles(math.pi, 0, 0), def.Trim)
	else
		add("Torso", torso, CFrame.new(0, torsoY, 0), def.Body)
	end
	local headY = torsoY + torso.Y / 2 + 1.3
	local headSize = if shape == "Squat" then Vector3.new(4.4, 3.6, 2) else Vector3.new(2.6, 2.4, 2.4)
	if shape == "Crab" then
		headY = torsoY + 1.6
		headSize = Vector3.new(3, 1.2, 1.2)
	end
	add("Head", headSize, CFrame.new(0, headY, 0), if shape == "Squat" then def.Trim else def.Body)
	for _, x in { -0.6, 0.6 } do
		add("Eye", Vector3.new(0.5, 0.5, 0.3), CFrame.new(x * (headSize.X / 2.6), headY + 0.2, -headSize.Z / 2 - 0.1), def.Eyes, nil, NEON)
	end

	local armY = torsoY + torso.Y / 2 - 1
	if shape == "Scarecrow" then
		add("Crossbar", Vector3.new(9, 0.8, 0.8), CFrame.new(0, armY, 0), def.Trim)
		add("HatBrim", Vector3.new(4, 0.4, 4), CFrame.new(0, headY + 1.4, 0), def.Trim)
		add("HatTop", Vector3.new(2, 1.6, 2), CFrame.new(0, headY + 2.3, 0), def.Trim)
	elseif shape == "Brute" or shape == "Golem" then
		for _, x in { -1, 1 } do
			add("Arm", Vector3.new(1.8, 5, 1.8), CFrame.new(x * (torso.X / 2 + 1), armY - 1.6, 0), def.Body)
			add("Shoulder", Vector3.new(2.4, 1.6, 2.4), CFrame.new(x * (torso.X / 2 + 1), armY + 1, 0), def.Trim,
				nil, if shape == "Golem" then NEON else nil)
		end
	elseif shape == "Spiky" then
		for i = -1, 1 do
			add("Spike", Vector3.new(1, 2.4, 2), CFrame.new(i * 1.2, torsoY + torso.Y / 2 + 0.6, 0.6), def.Trim)
		end
		add("Snout", Vector3.new(1.4, 1, 1.6), CFrame.new(0, headY - 0.3, -2), def.Body)
	elseif shape == "Tall" then
		add("Hood", Vector3.new(3, 2.6, 3), CFrame.new(0, headY + 1.4, 0), def.Trim)
		for _, x in { -1, 1 } do
			add("Arm", Vector3.new(0.9, 6, 0.9), CFrame.new(x * 1.9, armY - 2.4, -0.4), def.Body)
		end
	elseif shape == "Crab" then
		for _, x in { -1, 1 } do
			add("Claw", Vector3.new(2.6, 2.2, 2.6), CFrame.new(x * 4.4, torsoY + 0.6, -2.4), def.Trim, BALL)
		end
	elseif shape == "Floating" then
		add("Halo", Vector3.new(4, 0.3, 4), CFrame.new(0, headY + 1.4, 0), def.Eyes, nil, NEON)
	elseif shape == "Squat" then
		add("Crest", Vector3.new(4.8, 1.6, 0.6), CFrame.new(0, headY + 2.2, 0), def.Eyes, nil, NEON)
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, (headY + 3.2) * s, 0)
	gui.MaxDistance = 140
	gui.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromHex("#FF4D6D")
	label.TextStrokeTransparency = 0.2
	label.Text = def.Name
	label.Parent = gui

	return m
end

return GuardianRig
