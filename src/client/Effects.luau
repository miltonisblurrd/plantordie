--!strict
-- Reduced effects: disables every particle, sparkle, fire, smoke and trail in the workspace
-- (including ones spawned later) and restores them when turned back off. Also the shared
-- pop tween used for planting, growth stages and fusion claims.

local TweenService = game:GetService("TweenService")

local Settings = require(script.Parent.Settings)

local Effects = {}

local reduced = false

-- Speed trails are throttled by client/TrailFx instead of switched off.
local function isFx(inst: Instance): boolean
	if inst:GetAttribute("TrailFx") then
		return false
	end
	return inst:IsA("ParticleEmitter") or inst:IsA("Sparkles") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Trail")
end

local function applyTo(inst: Instance)
	if not isFx(inst) then
		return
	end
	local fx = inst :: any
	if reduced then
		if inst:GetAttribute("FxWasEnabled") == nil then
			inst:SetAttribute("FxWasEnabled", fx.Enabled)
		end
		fx.Enabled = false
	else
		local was = inst:GetAttribute("FxWasEnabled")
		if was ~= nil then
			fx.Enabled = was
			inst:SetAttribute("FxWasEnabled", nil)
		end
	end
end

function Effects.reduced(): boolean
	return reduced
end

-- Short scale-up pop (0.25 s, Back easing) on a model. Skipped under reduced effects.
function Effects.pop(model: Model, from: number?)
	if reduced or not model.Parent then
		return
	end
	local target = model:GetScale()
	local v = Instance.new("NumberValue")
	v.Value = target * (from or 0.6)
	model:ScaleTo(v.Value)
	v.Changed:Connect(function(x)
		if model.Parent then
			model:ScaleTo(x)
		end
	end)
	local t = TweenService:Create(v, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = target })
	t.Completed:Connect(function()
		v:Destroy()
	end)
	t:Play()
end

function Effects.start()
	workspace.DescendantAdded:Connect(function(inst)
		if reduced then
			applyTo(inst)
		end
	end)
	Settings.onChanged(function(v)
		if v.reducedEffects == reduced then
			return
		end
		reduced = v.reducedEffects
		for _, inst in workspace:GetDescendants() do
			applyTo(inst)
		end
	end)
end

return Effects
