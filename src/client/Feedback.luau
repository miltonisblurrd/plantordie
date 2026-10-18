--!strict
-- Consistent short feedback derived from state changes, so it only fires for things the server
-- actually did: purchases (Buy), night warning, wave clear, fusion ready, and the fusion claim pop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local FusionData = require(ReplicatedStorage.Shared.Fusion)
local State = require(script.Parent.State)
local Sfx = require(script.Parent.Sfx)
local Effects = require(script.Parent.Effects)

local Feedback = {}

local function count(t: { [string]: any }): number
	local n = 0
	for _, v in t do
		if v then
			n += 1
		end
	end
	return n
end

-- Monotonic purchase counter: any increase means a purchase went through.
local function owned(s: State.Snapshot): number
	local n = s.lanesUnlocked + s.houseTier + s.shovelTier + count(s.biomesUnlocked) + count(s.water :: any)
	for _, slot in s.fusion do
		if slot.unlocked then
			n += 1
		end
	end
	return n
end

local function padCore(machineId: string): BasePart?
	local snap = State.snapshot
	local m = FusionData.Machines[machineId]
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	local plot = snap and plots and plots:FindFirstChild(`Plot_{snap.plotIndex}`)
	local model = plot and m and plot:FindFirstChild(m.Pad)
	local core = model and model:FindFirstChild("Core")
	return if core and core:IsA("BasePart") then core else nil
end

local function popPart(part: BasePart)
	if Effects.reduced() then
		return
	end
	local size = part.Size
	local up = TweenService:Create(part, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = size * 1.25 })
	local down = TweenService:Create(part, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size })
	up.Completed:Connect(function()
		down:Play()
	end)
	up:Play()
end

function Feedback.start()
	local prev: State.Snapshot? = nil
	State.onSnapshot(function(s)
		local p = prev
		prev = s
		if not p then
			return
		end
		if owned(s) > owned(p) then
			Sfx.play("Buy")
		end
		local pd, sd = p.defense, s.defense
		if pd and sd and pd.active and not sd.active and not sd.lost then
			Sfx.play("WaveClear")
		end
		for id, slot in s.fusion do
			local old = p.fusion[id]
			if old and old.state ~= "empty" and slot.state == "empty" and slot.runId == old.runId then
				local core = padCore(id)
				if core then
					popPart(core)
				end
			end
		end
	end)

	local warned, readyRuns = false, {} :: { [string]: number }
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local now = State.now()
		local dn = State.dayNight
		local inWarning = dn ~= nil and dn.phase == "Day" and dn.endsAt - now <= Config.Defense.WarningSeconds
		if inWarning and not warned then
			Sfx.play("NightWarning")
		end
		warned = inWarning
		local s = State.snapshot
		if s then
			for id, slot in s.fusion do
				if slot.state ~= "empty" and now >= slot.endsAt and readyRuns[id] ~= slot.runId then
					readyRuns[id] = slot.runId
					Sfx.play("FusionDone")
				end
			end
		end
	end)
end

return Feedback
