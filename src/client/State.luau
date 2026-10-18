--!strict
-- Last state received from the server. Controllers subscribe; nothing here computes game values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Snapshot = {
	money: number,
	incomePerSec: number,
	houseTier: number,
	houseName: string,
	houseHp: number,
	houseMaxHp: number,
	houseSlots: number,
	plantedCount: number,
	seeds: { [string]: number },
	plants: { [string]: { id: string, species: string, rarity: string, size: string, variant: string } },
	lanesUnlocked: number,
	biomesUnlocked: { [string]: boolean },
	plotIndex: number,
	area: string,
	event: { name: string, endsAt: number }?,
	persistent: boolean,
}

export type DayNightInfo = { phase: string, endsAt: number, duration: number, night: number }

local State = {}
function State.remote(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end
State.snapshot = nil :: Snapshot?
State.dayNight = nil :: DayNightInfo?

local snapshotListeners: { (Snapshot) -> () } = {}
local dayNightListeners: { (DayNightInfo) -> () } = {}

function State.onSnapshot(cb: (Snapshot) -> ())
	table.insert(snapshotListeners, cb)
	if State.snapshot then
		task.spawn(cb, State.snapshot)
	end
end

function State.onDayNight(cb: (DayNightInfo) -> ())
	table.insert(dayNightListeners, cb)
	if State.dayNight then
		task.spawn(cb, State.dayNight)
	end
end

function State.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local stateSync = remotes:WaitForChild("StateSync") :: RemoteEvent
	local dayNight = remotes:WaitForChild("DayNight") :: RemoteEvent
	local request = remotes:WaitForChild("RequestState") :: RemoteEvent

	stateSync.OnClientEvent:Connect(function(snap: Snapshot)
		State.snapshot = snap
		for _, cb in snapshotListeners do
			task.spawn(cb, snap)
		end
	end)
	dayNight.OnClientEvent:Connect(function(phase: string, endsAt: number, duration: number, night: number)
		local info = { phase = phase, endsAt = endsAt, duration = duration, night = night }
		State.dayNight = info
		for _, cb in dayNightListeners do
			task.spawn(cb, info)
		end
	end)
	request:FireServer()
end

return State
