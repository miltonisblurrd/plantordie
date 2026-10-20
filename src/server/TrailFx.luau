--!strict
-- The equipped speed trail on every character: a Trail between two root attachments plus a
-- themed ParticleEmitter. Built on the server so everyone sees it. Clients gate the emitter
-- on movement and reduced effects (client/TrailFx); the Trail only draws while moving anyway.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trails = require(ReplicatedStorage.Shared.Trails)
local Data = require(script.Parent.Data)

local TrailFx = {}

local function sequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for i, c in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(points)
end

function TrailFx.apply(player: Player)
	local session = Data.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not session or not root or not root:IsA("BasePart") then
		return
	end
	for _, old in root:GetChildren() do
		if string.sub(old.Name, 1, 10) == "SpeedTrail" then
			old:Destroy()
		end
	end
	local def = Trails.ById[session.data.trails.equipped] or Trails.ById[Trails.DefaultId]

	local a0 = Instance.new("Attachment")
	a0.Name = "SpeedTrailTop"
	a0.Position = Vector3.new(0, def.Width / 2, 0.6)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "SpeedTrailBottom"
	a1.Position = Vector3.new(0, -def.Width / 2, 0.6)
	a1.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "SpeedTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = sequence(def.Colors)
	trail.LightEmission = def.LightEmission
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.Lifetime = 0.45
	trail.MinLength = 0.2
	trail.FaceCamera = true
	trail:SetAttribute("TrailFx", true)
	trail.Parent = root

	local p = def.Particle
	if p then
		local fx = Instance.new("ParticleEmitter")
		fx.Name = "SpeedTrailFx"
		fx.Texture = p.Texture
		fx.Color = sequence(p.Colors)
		fx.LightEmission = p.LightEmission
		fx.Size = NumberSequence.new(p.Size, 0)
		fx.Transparency = NumberSequence.new(0.1, 1)
		fx.Lifetime = NumberRange.new(p.Lifetime * 0.7, p.Lifetime)
		fx.Speed = NumberRange.new(p.Speed * 0.5, p.Speed)
		fx.SpreadAngle = Vector2.new(35, 35)
		fx.EmissionDirection = Enum.NormalId.Back
		fx.Rotation = NumberRange.new(0, 360)
		fx.RotSpeed = NumberRange.new(-90, 90)
		fx.Rate = p.Rate
		fx.Enabled = false
		fx:SetAttribute("BaseRate", p.Rate)
		fx:SetAttribute("TrailFx", true)
		fx.Parent = root
	end
end

function TrailFx.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			TrailFx.apply(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Data.onLoaded(function(player)
		TrailFx.apply(player)
	end)
end

return TrailFx
