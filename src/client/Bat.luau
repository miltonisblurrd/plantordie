--!strict
-- Bat: swing on click/tap (local tween + whoosh), then the server picks the target. BatHit plays
-- the spark and bonk; the victim also gets the knockback velocity, since its client owns physics.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Sfx = require(script.Parent.Sfx)

local Bat = {}

local player = Players.LocalPlayer
local lastSwing = 0

local function swing(tool: Tool)
	local base = CFrame.new(0, -0.4, 0)
	local wind = TweenService:Create(tool, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Grip = base * CFrame.Angles(math.rad(40), 0, math.rad(-30)) })
	local through = TweenService:Create(tool, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Grip = base * CFrame.Angles(math.rad(-90), 0, math.rad(60)) })
	local back = TweenService:Create(tool, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Grip = base })
	wind.Completed:Once(function()
		through:Play()
	end)
	through.Completed:Once(function()
		back:Play()
	end)
	wind:Play()
end

local function onActivated(tool: Tool)
	local now = os.clock()
	if Config.Bat.Cooldown > 0 and now - lastSwing < Config.Bat.Cooldown then
		return
	end
	lastSwing = now
	swing(tool)
	Sfx.play("Whoosh")
	State.remote("SwingBat"):FireServer()
end

local function hookTool(inst: Instance)
	if inst:IsA("Tool") and inst.Name == "Bat" and not inst:GetAttribute("Hooked") then
		inst:SetAttribute("Hooked", true)
		inst.Activated:Connect(function()
			onActivated(inst)
		end)
	end
end

local function spark(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "BatFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(0, 1, 0)
	anchor.Parent = workspace
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(Color3.fromHex("#FFF27A"), Color3.fromHex("#FF9F1C"))
	burst.LightEmission = 0.9
	burst.Size = NumberSequence.new(0.8, 0)
	burst.Speed = NumberRange.new(12, 20)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Lifetime = NumberRange.new(0.25, 0.45)
	burst.Rate = 0
	burst.Parent = anchor
	burst:Emit(24)
	Debris:AddItem(anchor, 1)
end

local function onHit(position: Vector3, velocity: Vector3?)
	if typeof(position) == "Vector3" then
		spark(position)
	end
	Sfx.play("Bonk")
	if typeof(velocity) ~= "Vector3" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = velocity
	end
	if hum then
		hum.PlatformStand = true
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		task.delay(Config.Bat.StunSeconds, function()
			if hum.Parent then
				hum.PlatformStand = false
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end
end

function Bat.start()
	local function watch(container: Instance)
		for _, c in container:GetChildren() do
			hookTool(c)
		end
		container.ChildAdded:Connect(hookTool)
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
	State.remote("BatHit").OnClientEvent:Connect(onHit)
end

return Bat
