--!strict
-- Neon / Mega maker on a plot pad. The server sets attributes on the model; the client's
-- Fusion controller reads them for the billboard timer and the panel. Cheap: ~12 parts.
--   Unlocked (bool), State ("empty" | "fusing"), EndsAt, StartedAt, Species, RunId

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FusionData = require(ReplicatedStorage.Shared.Fusion)
local Format = require(ReplicatedStorage.Shared.Format)
local Parts = require(script.Parent.Parent.Parts)

local Machine = {}

local IDLE = Color3.fromRGB(70, 70, 80)

function Machine.build(machineId: string, plotIndex: number, cf: CFrame, parent: Instance): Model
	local def = FusionData.Machines[machineId]
	local m = Parts.model(def.Pad, parent)
	m:SetAttribute("PlotIndex", plotIndex)
	m:SetAttribute("Machine", machineId)
	m:SetAttribute("Unlocked", false)
	m:SetAttribute("State", "empty")
	m:SetAttribute("EndsAt", 0)
	m:SetAttribute("StartedAt", 0)
	m:SetAttribute("RunId", 0)

	local pad = Parts.make({
		Name = "Pad", Parent = m, Color = Color3.fromRGB(60, 60, 70),
		Size = Vector3.new(12, 0.6, 12), CFrame = cf * CFrame.new(0, 0.3, 0),
	})
	m.PrimaryPart = pad
	Parts.make({
		Name = "Ring", Parent = m, Color = def.Color, Material = Enum.Material.Neon,
		CanCollide = false, Size = Vector3.new(12.4, 0.2, 12.4), CFrame = cf * CFrame.new(0, 0.55, 0),
		Transparency = 0.5,
	})
	for i, off in { Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4) } do
		Parts.make({
			Name = "Socket" .. i, Parent = m, Color = Color3.fromRGB(90, 90, 100),
			Size = Vector3.new(2, 1, 2), CFrame = cf * CFrame.new(off.X, 1.1, off.Z),
		})
	end
	Parts.make({
		Name = "Base", Parent = m, Color = Color3.fromRGB(45, 45, 55),
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 6, 6),
		CFrame = cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	Parts.make({
		Name = "Chamber", Parent = m, Color = Color3.fromRGB(200, 230, 255), Material = Enum.Material.Glass,
		Transparency = 0.6, CanCollide = false, Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 4.6, 4.6),
		CFrame = cf * CFrame.new(0, 4.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local core = Parts.make({
		Name = "Core", Parent = m, Color = IDLE, Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = cf * CFrame.new(0, 4.8, 0),
		CanCollide = false,
	})
	Parts.make({
		Name = "Cap", Parent = m, Color = Color3.fromRGB(45, 45, 55),
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 5.4, 5.4),
		CFrame = cf * CFrame.new(0, 8.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local sign = Parts.make({
		Name = "Sign", Parent = m, Color = Color3.fromHex("#1E2A22"),
		Size = Vector3.new(10, 2.4, 0.4), CFrame = cf * CFrame.new(0, 1.8, -6.6),
	})
	Parts.surfaceText(sign, Enum.NormalId.Front, string.upper(def.Name), def.Color)

	local bb = Instance.new("BillboardGui")
	bb.Name = "Status"
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffset = Vector3.new(0, 4.5, 0)
	bb.MaxDistance = 120
	bb.LightInfluence = 0
	bb.Parent = core
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = `Build for {Format.money(def.UnlockCost)}`
	label.Parent = bb

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FusionPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Machine", machineId)
	prompt.Parent = pad
	return m
end

-- Mirrors a saved fusion slot onto the model (nil = plot released).
function Machine.apply(m: Model, slot: { unlocked: boolean, state: string, runId: number, species: string?, startedAt: number, endsAt: number }?)
	local def = FusionData.Machines[m:GetAttribute("Machine") :: string]
	local unlocked = slot ~= nil and slot.unlocked
	local fusing = slot ~= nil and slot.state ~= "empty"
	m:SetAttribute("Unlocked", unlocked)
	m:SetAttribute("State", if slot then slot.state else "empty")
	m:SetAttribute("EndsAt", if slot then slot.endsAt else 0)
	m:SetAttribute("StartedAt", if slot then slot.startedAt else 0)
	m:SetAttribute("RunId", if slot then slot.runId else 0)
	m:SetAttribute("Species", if slot then slot.species else nil)
	local core = m:FindFirstChild("Core") :: BasePart?
	if not core then
		return
	end
	core.Color = if fusing then def.Color elseif unlocked then def.Color:Lerp(IDLE, 0.6) else IDLE
	core.Material = if fusing then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local light = core:FindFirstChildOfClass("PointLight")
	if fusing and not light then
		local l = Instance.new("PointLight")
		l.Color = def.Color
		l.Range = 12
		l.Brightness = 1.5
		l.Parent = core
	elseif not fusing and light then
		light:Destroy()
	end
end

return Machine
