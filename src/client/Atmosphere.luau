--!strict
-- Biome mood: when the server says you're in a biome, blend a local Atmosphere (haze, distance
-- decay, density) and ColorCorrection (tint, saturation, contrast, brightness) to that biome's
-- attributes (World/BiomeKit Kit.mood); back to the home look elsewhere. Fog stays with Event.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)

local Atmosphere = {}

local HOME = {
	color = Color3.fromRGB(200, 232, 255),
	decay = Color3.fromRGB(150, 200, 255),
	density = 0.25,
}
local BLEND = TweenInfo.new(1.6, Enum.EasingStyle.Sine)

type Weather = {
	color: Color3,
	rate: number,
	speed: NumberRange,
	lifetime: NumberRange,
	size: NumberSequence,
	accel: Vector3,
	spread: Vector2,
	light: number,
	rot: NumberRange,
	drag: number?,
}

local WEATHER: { [string]: Weather } = {
	GreenMeadows = { color = Color3.fromRGB(120, 210, 80), rate = 12, speed = NumberRange.new(2, 5), lifetime = NumberRange.new(2.4, 3.6), size = NumberSequence.new(0.35, 0.1), accel = Vector3.new(1, -4, 0.4), spread = Vector2.new(30, 30), light = 0.1, rot = NumberRange.new(-40, 40) },
	MushroomForest = { color = Color3.fromRGB(220, 180, 255), rate = 18, speed = NumberRange.new(0.4, 1.4), lifetime = NumberRange.new(3, 5), size = NumberSequence.new(0.25, 0.05), accel = Vector3.new(0, 1.2, 0), spread = Vector2.new(40, 40), light = 0.45, rot = NumberRange.new(0, 0), drag = 1 },
	CactusCanyon = { color = Color3.fromRGB(214, 170, 110), rate = 22, speed = NumberRange.new(6, 12), lifetime = NumberRange.new(1.2, 2), size = NumberSequence.new(0.2, 0.05), accel = Vector3.new(8, -1, 2), spread = Vector2.new(15, 8), light = 0, rot = NumberRange.new(0, 0), drag = 0.4 },
	InfernoJungle = { color = Color3.fromRGB(255, 90, 30), rate = 28, speed = NumberRange.new(2, 5), lifetime = NumberRange.new(1.2, 2.2), size = NumberSequence.new(0.28, 0.02), accel = Vector3.new(0, 6, 0), spread = Vector2.new(25, 25), light = 0.9, rot = NumberRange.new(0, 0) },
	FrostbiteGarden = { color = Color3.fromRGB(235, 248, 255), rate = 40, speed = NumberRange.new(2, 5), lifetime = NumberRange.new(2.5, 4), size = NumberSequence.new(0.18, 0.05), accel = Vector3.new(1.5, -6, 0), spread = Vector2.new(20, 12), light = 0.2, rot = NumberRange.new(-20, 20) },
	EnchantedGrove = { color = Color3.fromRGB(180, 140, 255), rate = 16, speed = NumberRange.new(0.6, 2), lifetime = NumberRange.new(2, 3.5), size = NumberSequence.new(0.22, 0.04), accel = Vector3.new(0, 1.5, 0), spread = Vector2.new(50, 50), light = 0.85, rot = NumberRange.new(0, 0) },
	TropicalParadise = { color = Color3.fromRGB(255, 150, 170), rate = 10, speed = NumberRange.new(1.5, 3.5), lifetime = NumberRange.new(2.5, 4), size = NumberSequence.new(0.32, 0.08), accel = Vector3.new(2, -3, 1), spread = Vector2.new(25, 20), light = 0.15, rot = NumberRange.new(-50, 50) },
	CoralKingdom = { color = Color3.fromRGB(140, 220, 255), rate = 20, speed = NumberRange.new(1, 3), lifetime = NumberRange.new(2, 3.5), size = NumberSequence.new(0.3, 0.45), accel = Vector3.new(0, 3, 0), spread = Vector2.new(30, 30), light = 0.35, rot = NumberRange.new(0, 0), drag = 1.2 },
	AutumnWoods = { color = Color3.fromRGB(220, 110, 30), rate = 18, speed = NumberRange.new(2, 5), lifetime = NumberRange.new(2.2, 3.4), size = NumberSequence.new(0.38, 0.08), accel = Vector3.new(3, -5, 1), spread = Vector2.new(28, 18), light = 0.1, rot = NumberRange.new(-60, 60) },
	SkyIslands = { color = Color3.fromRGB(255, 255, 255), rate = 8, speed = NumberRange.new(0.4, 1.2), lifetime = NumberRange.new(3, 5), size = NumberSequence.new(1.2, 2.2), accel = Vector3.new(1, 0.4, 0), spread = Vector2.new(40, 20), light = 0.15, rot = NumberRange.new(0, 0), drag = 2 },
	CrystalCaverns = { color = Color3.fromRGB(120, 240, 255), rate = 22, speed = NumberRange.new(0.5, 1.6), lifetime = NumberRange.new(1.6, 2.8), size = NumberSequence.new(0.16, 0.04), accel = Vector3.new(0, 0.8, 0), spread = Vector2.new(60, 60), light = 1, rot = NumberRange.new(0, 0) },
	ToxicSwamp = { color = Color3.fromRGB(160, 255, 40), rate = 16, speed = NumberRange.new(0.8, 2), lifetime = NumberRange.new(2, 3.5), size = NumberSequence.new(0.35, 0.5), accel = Vector3.new(0, 2.2, 0), spread = Vector2.new(35, 35), light = 0.55, rot = NumberRange.new(0, 0), drag = 1 },
	AncientWilds = { color = Color3.fromRGB(190, 170, 130), rate = 10, speed = NumberRange.new(1, 3), lifetime = NumberRange.new(2, 3.2), size = NumberSequence.new(0.22, 0.04), accel = Vector3.new(2, -1, 0), spread = Vector2.new(20, 15), light = 0, rot = NumberRange.new(0, 0), drag = 0.6 },
	CosmicGarden = { color = Color3.fromRGB(200, 170, 255), rate = 24, speed = NumberRange.new(0.3, 1.2), lifetime = NumberRange.new(2, 4), size = NumberSequence.new(0.12, 0.02), accel = Vector3.new(0, 0.3, 0), spread = Vector2.new(80, 80), light = 1, rot = NumberRange.new(0, 0) },
	ForbiddenBloom = { color = Color3.fromRGB(255, 40, 80), rate = 14, speed = NumberRange.new(1, 2.5), lifetime = NumberRange.new(2.4, 3.8), size = NumberSequence.new(0.34, 0.06), accel = Vector3.new(0.6, -2, 0.4), spread = Vector2.new(30, 25), light = 0.4, rot = NumberRange.new(-40, 40) },
}

local function applyWeather(emitter: ParticleEmitter, id: string)
	local w = WEATHER[id]
	if not w then
		emitter.Enabled = false
		return
	end
	emitter.Enabled = true
	emitter.Color = ColorSequence.new(w.color)
	emitter.Rate = w.rate
	emitter.Speed = w.speed
	emitter.Lifetime = w.lifetime
	emitter.Size = w.size
	emitter.Acceleration = w.accel
	emitter.SpreadAngle = w.spread
	emitter.LightEmission = w.light
	emitter.Rotation = w.rot
	emitter.RotSpeed = w.rot
	emitter.Drag = w.drag or 0
	emitter.Transparency = NumberSequence.new(0.15, 1)
end

local function attachWeather(cloud: BasePart)
	local player = Players.LocalPlayer
	local function onCharacter(character: Model)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root or not root:IsA("BasePart") then
			return
		end
		cloud.CFrame = root.CFrame * CFrame.new(0, 6, 0)
		cloud.Parent = character
		local weld = cloud:FindFirstChild("Weld")
		if not weld then
			local w = Instance.new("Weld")
			w.Name = "Weld"
			w.Part0 = root
			w.Part1 = cloud
			w.C0 = CFrame.new(0, 6, 0)
			w.Parent = cloud
		end
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

local function attr<T>(model: Instance, name: string, fallback: T): T
	local v = model:GetAttribute(name)
	return if v ~= nil and typeof(v) == typeof(fallback) then v :: any else fallback
end

function Atmosphere.start()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BiomeTint"
	cc.Parent = Lighting
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		local made = Instance.new("Atmosphere")
		made.Name = "BiomeAtmosphere"
		made.Color = HOME.color
		made.Decay = HOME.decay
		made.Density = HOME.density
		made.Offset = 0.1
		made.Glare = 0.1
		made.Haze = 1.2
		made.Parent = Lighting
		atmo = made
	end
	local cloud = Instance.new("Part")
	cloud.Name = "BiomeWeather"
	cloud.Size = Vector3.new(28, 16, 28)
	cloud.Transparency = 1
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.Massless = true
	cloud.Anchored = false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BiomeFx"
	emitter.Enabled = false
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Parent = cloud
	attachWeather(cloud)
	local current = ""
	State.onSnapshot(function(s)
		if s.areaBiome == current then
			return
		end
		current = s.areaBiome
		applyWeather(emitter, current)
		local world = workspace:FindFirstChild("World")
		local biomes = world and world:FindFirstChild("Biomes")
		local model = biomes and current ~= "" and biomes:FindFirstChild("Biome_" .. current)
		if model then
			TweenService:Create(cc, BLEND, {
				TintColor = attr(model, "Tint", Color3.new(1, 1, 1)),
				Saturation = attr(model, "Saturation", 0.1),
				Contrast = attr(model, "Contrast", 0.05),
				Brightness = attr(model, "Brightness", 0),
			}):Play()
			TweenService:Create(atmo :: Atmosphere, BLEND, {
				Color = attr(model, "AtmoColor", HOME.color),
				Decay = attr(model, "AtmoDecay", HOME.decay),
				Density = attr(model, "AtmoDensity", HOME.density),
			}):Play()
		else
			TweenService:Create(cc, BLEND, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0, Brightness = 0 }):Play()
			TweenService:Create(atmo :: Atmosphere, BLEND, { Color = HOME.color, Decay = HOME.decay, Density = HOME.density }):Play()
		end
	end)
end

return Atmosphere
