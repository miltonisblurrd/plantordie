--!strict
-- Player profiles: session-locked load with retries, safe saves, autosave, BindToClose flush.
--
-- Invariants:
--   * A profile is written only if it loaded successfully this session (session.loaded).
--   * A load that fails after all retries kicks the player and never writes their key.
--   * A save never overwrites a record whose lock belongs to another server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Schema = require(script.Schema)
local Store = require(script.Store)

export type Profile = Schema.Profile

export type Session = {
	player: Player,
	key: string,
	data: Profile,
	loaded: boolean,
	lostLock: boolean,
	saving: boolean,
	released: boolean,
	joinedAt: number,
}

local Data = {}

local sessions: { [Player]: Session } = {}
-- userId -> true while that user's final save is in flight; a same-server rejoin waits on it,
-- because a matching JobId would otherwise let the new load read the pre-save record.
local releasing: { [number]: boolean } = {}
local loadedCallbacks: { (Player, Session) -> () } = {}
local releasingCallbacks: { (Player, Session) -> () } = {}
local changedCallbacks: { (Player, Session) -> () } = {}

local function keyFor(userId: number): string
	return Config.Data.KeyPrefix .. tostring(userId)
end

local function backoff(attempt: number)
	task.wait(Config.Data.RetryBaseDelay * 2 ^ (attempt - 1))
end

type LoadResult = "Ok" | "Locked" | "Refused" | "Error"

local function tryLoad(key: string): (LoadResult, Profile?, string?)
	local result: LoadResult = "Error"
	local record: Profile? = nil
	local reason: string? = nil
	local ok, err = pcall(Store.update, key, function(old: any): any
		-- UpdateAsync may call this more than once; reset state on every call.
		result, record, reason = "Error", nil, nil
		local lock = type(old) == "table" and old.lock or nil
		if
			lock
			and lock.jobId ~= game.JobId
			and os.time() - (tonumber(lock.time) or 0) < Config.Data.LockStaleSeconds
		then
			result, reason = "Locked", `session locked by server {lock.jobId}`
			return nil
		end
		local migrated, why = Schema.migrate(old)
		if not migrated then
			result, reason = "Refused", why
			return nil
		end
		migrated.lock = { jobId = game.JobId, time = os.time() }
		result, record = "Ok", migrated
		return migrated
	end)
	if not ok then
		return "Error", nil, tostring(err)
	end
	return result, record, reason
end

local function loadWithRetries(key: string): (Profile?, string?)
	local lastReason: string? = nil
	for attempt = 1, Config.Data.Retries do
		local result, record, reason = tryLoad(key)
		if result == "Ok" then
			return record, nil
		end
		lastReason = reason
		warn(`[Data] load {key} attempt {attempt}/{Config.Data.Retries} failed: {reason}`)
		if result == "Refused" then
			break -- retrying cannot fix a corrupt/newer record
		end
		if attempt < Config.Data.Retries then
			backoff(attempt)
		end
	end
	return nil, lastReason
end

local function writeOnce(session: Session, release: boolean): (boolean, string?)
	local snapshot = Store.deepCopy(session.data)
	snapshot.version = Config.Data.SchemaVersion
	snapshot.lock = if release then nil else { jobId = game.JobId, time = os.time() }
	local lost = false
	local ok, err = pcall(Store.update, session.key, function(old: any): any
		lost = false
		local lock = type(old) == "table" and old.lock or nil
		if lock and lock.jobId ~= game.JobId then
			lost = true
			return nil
		end
		return snapshot
	end)
	if not ok then
		return false, tostring(err)
	end
	if lost then
		session.lostLock = true
		return false, "session lock taken by another server"
	end
	return true, nil
end

-- Saves a session. Returns true if the record was written.
function Data.save(session: Session, release: boolean?): boolean
	if not session.loaded or session.lostLock or session.released then
		return false
	end
	while session.saving do
		task.wait(0.1)
	end
	if session.released then
		return false
	end
	session.saving = true
	local now = os.time()
	session.data.stats.playSeconds += now - session.joinedAt
	session.joinedAt = now
	local written = false
	for attempt = 1, Config.Data.Retries do
		local ok, reason = writeOnce(session, release == true)
		if ok then
			written = true
			break
		end
		warn(`[Data] save {session.key} attempt {attempt}/{Config.Data.Retries} failed: {reason}`)
		if session.lostLock then
			break
		end
		if attempt < Config.Data.Retries then
			backoff(attempt)
		end
	end
	if release then
		session.released = true
	end
	session.saving = false
	return written
end

local function onPlayerAdded(player: Player)
	if sessions[player] then
		return
	end
	local key = keyFor(player.UserId)
	local session: Session = {
		player = player,
		key = key,
		data = Schema.default(),
		loaded = false,
		lostLock = false,
		saving = false,
		released = false,
		joinedAt = os.time(),
	}
	sessions[player] = session

	local waitUntil = os.clock() + Config.Data.BindToCloseTimeout
	while releasing[player.UserId] and os.clock() < waitUntil do
		task.wait(0.2)
	end

	local record, reason = loadWithRetries(key)

	if not record then
		-- session.loaded stays false: Data.save refuses, Net gate rejects every remote.
		warn(`[Data] load {key} FAILED; kicking without saving. Reason: {reason}`)
		if player.Parent then
			player:Kick(Config.Data.KickMessage)
		end
		return
	end

	session.data = record
	session.loaded = true
	session.joinedAt = os.time()
	record.stats.joins += 1
	record.stats.lastJoin = os.time()

	if not player.Parent then
		-- Left while loading: hand the lock back immediately.
		Data.save(session, true)
		sessions[player] = nil
		return
	end

	for _, cb in loadedCallbacks do
		task.spawn(cb, player, session)
	end
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if session.loaded then
		releasing[player.UserId] = true
		for _, cb in releasingCallbacks do
			pcall(cb, player, session)
		end
		Data.save(session, true)
		releasing[player.UserId] = nil
	end
end

function Data.get(player: Player): Session?
	local s = sessions[player]
	if s and s.loaded then
		return s
	end
	return nil
end

function Data.isLoaded(player: Player): boolean
	return Data.get(player) ~= nil
end

function Data.onLoaded(cb: (Player, Session) -> ())
	table.insert(loadedCallbacks, cb)
	for player, s in sessions do
		if s.loaded then
			task.spawn(cb, player, s)
		end
	end
end

function Data.onReleasing(cb: (Player, Session) -> ())
	table.insert(releasingCallbacks, cb)
end

function Data.onChanged(cb: (Player, Session) -> ())
	table.insert(changedCallbacks, cb)
end

-- Mutate a loaded profile and notify listeners (HUD sync etc.).
function Data.update(player: Player, mutate: (Profile) -> ()): boolean
	local s = Data.get(player)
	if not s then
		return false
	end
	mutate(s.data)
	for _, cb in changedCallbacks do
		task.spawn(cb, player, s)
	end
	return true
end

-- Idempotency ledger for ProcessReceipt. Returns false if already granted.
function Data.recordReceipt(profile: Profile, purchaseId: string): boolean
	local ledger = profile.receiptLedger
	if ledger.seen[purchaseId] then
		return false
	end
	ledger.seen[purchaseId] = true
	table.insert(ledger.order, purchaseId)
	while #ledger.order > Config.Data.ReceiptLedgerCap do
		local oldest = table.remove(ledger.order, 1) :: string
		ledger.seen[oldest] = nil
	end
	return true
end

function Data.hasReceipt(profile: Profile, purchaseId: string): boolean
	return profile.receiptLedger.seen[purchaseId] == true
end

function Data.mode(): Store.Mode
	return Store.getMode()
end

function Data.start()
	Store.init()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end

	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for _, s in sessions do
				if s.loaded and not s.released then
					task.spawn(Data.save, s, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, s in sessions do
			if s.loaded and not s.released then
				pending += 1
				task.spawn(function()
					for _, cb in releasingCallbacks do
						pcall(cb, player, s)
					end
					Data.save(s, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + Config.Data.BindToCloseTimeout
		while (pending > 0 or next(releasing) ~= nil) and os.clock() < deadline do
			task.wait(0.1)
		end
		if pending > 0 or next(releasing) ~= nil then
			warn(`[Data] BindToClose timed out with {pending} saves pending`)
		end
	end)
end

return Data
