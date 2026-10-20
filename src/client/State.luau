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
	areaBiome: string, -- biome id, "" outside biomes
	shovelTier: number,
	bag: { [string]: number }, -- unbanked expedition seeds
	defense: DefenseInfo?,
	event: EventInfo?,
	water: { channel: boolean, sprinkler: boolean, pond: boolean },
	fusion: { [string]: FusionSlot },
	credits: { [string]: number },
	collection: { [string]: boolean }, -- "species|variant"
	growthBoostEndsAt: number,
	persistent: boolean,
	speed: number,
	treadmillLevel: number,
	trails: { owned: { [string]: boolean }, equipped: string },
}

export type FusionSlot = {
	unlocked: boolean,
	state: string, -- "empty" | "fusing" (ready = fusing and now >= endsAt)
	runId: number,
	species: string?,
	rarity: string?,
	size: string?,
	startedAt: number,
	endsAt: number,
}

export type EventInfo = {
	id: string,
	name: string,
	endsAt: number,
	currency: string,
	amount: number,
	packName: string,
	packCost: number,
	packProduct: string,
	quests: { { name: string, progress: number, goal: number, reward: number, done: boolean } },
}

export type DefenseInfo = {
	active: boolean,
	night: number,
	remaining: number,
	total: number,
	lost: boolean,
	boss: boolean,
	repairCost: number,
	repairNeeded: boolean,
	repairReadyAt: number,
	wilted: number,
	traps: { [string]: { readyAt: number, cost: number } },
}

export type DayNightInfo = { phase: string, endsAt: number, duration: number, night: number }

local State = {}
function State.remote(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end
State.snapshot = nil :: Snapshot?

-- Server clock for countdowns (os.time() on the client can drift).
function State.now(): number
	return workspace:GetServerTimeNow()
end
State.dayNight = nil :: DayNightInfo?
-- Latest speed total: from StateSync, and from SpeedGain between snapshots.
State.speed = 0

local snapshotListeners: { (Snapshot) -> () } = {}
local dayNightListeners: { (DayNightInfo) -> () } = {}
local speedListeners: { (number) -> () } = {}

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

function State.onSpeed(cb: (number) -> ())
	table.insert(speedListeners, cb)
	task.spawn(cb, State.speed)
end

function State.setSpeed(total: number)
	if total == State.speed then
		return
	end
	State.speed = total
	for _, cb in speedListeners do
		task.spawn(cb, total)
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
		State.setSpeed(snap.speed)
	end)
	local function setDayNight(phase: string, endsAt: number, duration: number, night: number)
		local cur = State.dayNight
		if cur and cur.phase == phase and cur.endsAt == endsAt and cur.night == night then
			return
		end
		local info = { phase = phase, endsAt = endsAt, duration = duration, night = night }
		State.dayNight = info
		for _, cb in dayNightListeners do
			task.spawn(cb, info)
		end
	end
	local function fromAttributes()
		local phase = ReplicatedStorage:GetAttribute("DayPhase")
		local endsAt = ReplicatedStorage:GetAttribute("DayEndsAt")
		if type(phase) == "string" and type(endsAt) == "number" then
			local duration = ReplicatedStorage:GetAttribute("DayDuration")
			local night = ReplicatedStorage:GetAttribute("DayNightNumber")
			setDayNight(phase, endsAt, if type(duration) == "number" then duration else 0, if type(night) == "number" then night else 0)
		end
	end
	dayNight.OnClientEvent:Connect(setDayNight)
	ReplicatedStorage:GetAttributeChangedSignal("DayEndsAt"):Connect(fromAttributes)
	fromAttributes()
	request:FireServer()
end

return State
