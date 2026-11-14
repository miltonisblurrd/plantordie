--!strict
-- Procedural stride for guardian rigs (tag "Guardian"). Each "Swing" Motor6D (legs and arms,
-- hinged at the top) swings with a cadence and reach driven by the root's replicated speed, so
-- feet match ground speed instead of sliding. The Chasing attribute widens the swing into an
-- aggressive sprint. Transform is local-only, so this costs the server nothing. Rigs farther
-- than MAX_DIST from the camera are skipped.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MAX_DIST = 220
local STRIDE = 7 -- studs travelled per full leg cycle at scale 1
local WALK_SWING = math.rad(30)
local CHASE_SWING = math.rad(55)

type Rig = { root: BasePart, motors: { Motor6D }, phase: number, amp: number }

local GuardianAnim = {}

local rigs: { [Model]: Rig } = {}

local function track(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model.PrimaryPart or model:WaitForChild("Root", 10)
	if not root or not root:IsA("BasePart") or not model.Parent then
		return
	end
	local motors: { Motor6D } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == "Swing" then
			table.insert(motors, d)
		end
	end
	rigs[model] = { root = root, motors = motors, phase = 0, amp = 0 }
end

function GuardianAnim.start()
	for _, m in CollectionService:GetTagged("Guardian") do
		task.spawn(track, m)
	end
	CollectionService:GetInstanceAddedSignal("Guardian"):Connect(function(m)
		task.spawn(track, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Guardian"):Connect(function(m)
		rigs[m :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		for model, rig in rigs do
			if not rig.root.Parent then
				rigs[model] = nil
				continue
			end
			if (rig.root.Position - eye).Magnitude > MAX_DIST or #rig.motors == 0 then
				continue
			end
			local v = rig.root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local scale = rig.root.Size.Y
			local chasing = model:GetAttribute("Chasing") == true
			local maxSwing = if chasing then CHASE_SWING else WALK_SWING
			local wantAmp = if speed < 0.5 then 0 else maxSwing * math.clamp(speed / 20, 0.4, 1)
			rig.amp += (wantAmp - rig.amp) * math.min(1, dt * 10)
			rig.phase = (rig.phase + dt * speed / (STRIDE * scale) * 2 * math.pi) % (2 * math.pi)
			for _, motor in rig.motors do
				local offset = (motor:GetAttribute("Phase") :: number?) or 0
				local arm = motor:GetAttribute("Arm") == true
				local swing = math.sin(rig.phase + offset + (if arm then math.pi else 0)) * rig.amp
				motor.Transform = CFrame.Angles(if arm then swing * 0.8 else swing, 0, 0)
			end
		end
	end)
end

return GuardianAnim
