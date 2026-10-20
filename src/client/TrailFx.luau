--!strict
-- Local gating for every character's speed-trail emitter (built by server/TrailFx): it only
-- emits while that character moves, and reduced effects cuts its Rate instead of hiding it.

local Players = game:GetService("Players")

local Settings = require(script.Parent.Settings)

local TrailFx = {}

local MOVING = 2 -- studs/s horizontal
local REDUCED_RATE = 0.25

function TrailFx.start()
	task.spawn(function()
		while true do
			local scale = if Settings.values.reducedEffects then REDUCED_RATE else 1
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				local fx = root and root:FindFirstChild("SpeedTrailFx")
				if root and root:IsA("BasePart") and fx and fx:IsA("ParticleEmitter") then
					local v = root.AssemblyLinearVelocity
					fx.Enabled = Vector3.new(v.X, 0, v.Z).Magnitude > MOVING
					local base = fx:GetAttribute("BaseRate")
					if type(base) == "number" then
						fx.Rate = base * scale
					end
				end
			end
			task.wait(0.15)
		end
	end)
end

return TrailFx
