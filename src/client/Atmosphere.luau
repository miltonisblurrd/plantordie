--!strict
-- Biome lighting tint zones: when the server says you're in a biome, tween a local
-- ColorCorrection to that biome's Tint attribute; back to neutral elsewhere.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)

local Atmosphere = {}

function Atmosphere.start()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BiomeTint"
	cc.Parent = Lighting
	local current = ""
	State.onSnapshot(function(s)
		if s.areaBiome == current then
			return
		end
		current = s.areaBiome
		local tint = Color3.new(1, 1, 1)
		local world = workspace:FindFirstChild("World")
		local biomes = world and world:FindFirstChild("Biomes")
		local model = biomes and current ~= "" and biomes:FindFirstChild("Biome_" .. current)
		if model then
			local t = model:GetAttribute("Tint")
			if typeof(t) == "Color3" then
				tint = t
			end
		end
		TweenService:Create(cc, TweenInfo.new(1.2), { TintColor = tint, Saturation = if model then 0.1 else 0 }):Play()
	end)
end

return Atmosphere
