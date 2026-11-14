--!strict
-- Biome mood: when the server says you're in a biome, blend a local Atmosphere (haze, distance
-- decay, density) and ColorCorrection (tint, saturation, contrast, brightness) to that biome's
-- attributes (World/BiomeKit Kit.mood); back to the home look elsewhere. Fog stays with Event.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)

local Atmosphere = {}

local HOME = {
	color = Color3.fromRGB(200, 232, 255),
	decay = Color3.fromRGB(150, 200, 255),
	density = 0.25,
}
local BLEND = TweenInfo.new(1.6, Enum.EasingStyle.Sine)

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
	local current = ""
	State.onSnapshot(function(s)
		if s.areaBiome == current then
			return
		end
		current = s.areaBiome
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
