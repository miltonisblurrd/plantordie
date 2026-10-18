--!strict
-- Server-authoritative day/night cycle. Broadcasts (phase, endsAt, duration, night) where endsAt is
-- workspace:GetServerTimeNow() time, so every client shows the same countdown.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(script.Parent.Net)

export type Phase = "Day" | "Night"

local D = Config.DayNight

local DayNight = {}

local phase: Phase = "Day"
local startedAt = 0
local endsAt = 0
local night = 0
local listeners: { (Phase, number) -> () } = {}

function DayNight.phase(): Phase
	return phase
end

function DayNight.nightNumber(): number
	return night
end

function DayNight.onPhaseChanged(cb: (Phase, number) -> ())
	table.insert(listeners, cb)
end

function DayNight.sendTo(player: Player)
	local duration = if phase == "Day" then D.DaySeconds else D.NightSeconds
	Net.fire("DayNight", player, phase, endsAt, duration, night)
end

local function broadcast()
	local duration = if phase == "Day" then D.DaySeconds else D.NightSeconds
	Net.fireAll("DayNight", phase, endsAt, duration, night)
	for _, cb in listeners do
		task.spawn(cb, phase, night)
	end
end

local function clockFor(now: number): number
	local t = math.clamp((now - startedAt) / (endsAt - startedAt), 0, 1)
	local c = if phase == "Day"
		then D.DayClockStart + (D.DayClockEnd - D.DayClockStart) * t
		else D.DayClockEnd + (D.NightClockEnd - D.DayClockEnd) * t
	return c % 24
end

local function enter(newPhase: Phase)
	phase = newPhase
	if phase == "Night" then
		night += 1
	end
	startedAt = workspace:GetServerTimeNow()
	endsAt = startedAt + (if phase == "Day" then D.DaySeconds else D.NightSeconds)
	broadcast()
end

function DayNight.start()
	Lighting.ClockTime = D.DayClockStart
	enter("Day")
	task.spawn(function()
		while true do
			task.wait(1)
			local now = workspace:GetServerTimeNow()
			if now >= endsAt then
				enter(if phase == "Day" then "Night" else "Day")
			end
			local target = clockFor(now + 1)
			if target < Lighting.ClockTime then
				Lighting.ClockTime = target -- midnight wrap; tweening would run backwards
			else
				TweenService:Create(Lighting, TweenInfo.new(1, Enum.EasingStyle.Linear), { ClockTime = target }):Play()
			end
		end
	end)
end

return DayNight
