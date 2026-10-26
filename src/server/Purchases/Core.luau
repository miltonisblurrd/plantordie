--!strict
-- Pure receipt ledger (spec §14). Order is fixed: record the PurchaseId (+ a pending grant) in
-- the profile, save, and only if the save succeeded apply the grant. A failed save rolls the
-- ledger entry back and returns NotProcessedYet, so Roblox retries and nothing was granted.
-- A crash after the save but before the grant leaves the pending entry, applied on next load.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Treadmill = require(ReplicatedStorage.Shared.Treadmill)
local Boosts = require(ReplicatedStorage.Shared.RobuxBoosts)

export type Pending = { key: string, arg: string? }
export type Ledger = { order: { string }, seen: { [string]: boolean }, pending: { [string]: Pending } }
export type Result = "Granted" | "NotProcessedYet"

local Core = {}

-- PurchaseIds currently between ledger write and grant on this server.
local inFlight: { [string]: boolean } = {}

local function trim(ledger: Ledger)
	while #ledger.order > Config.Data.ReceiptLedgerCap do
		local oldest = table.remove(ledger.order, 1) :: string
		if not ledger.pending[oldest] then
			ledger.seen[oldest] = nil
		end
	end
end

local function rollback(ledger: Ledger, purchaseId: string)
	ledger.seen[purchaseId] = nil
	ledger.pending[purchaseId] = nil
	local i = table.find(ledger.order, purchaseId)
	if i then
		table.remove(ledger.order, i)
	end
end

-- save() yields and returns true if the record was written. grant() must not yield.
function Core.process(
	ledger: Ledger,
	purchaseId: string,
	key: string,
	arg: string?,
	save: () -> boolean,
	grant: (key: string, arg: string?) -> ()
): Result
	if inFlight[purchaseId] then
		return "NotProcessedYet"
	end
	if ledger.seen[purchaseId] then
		local pending = ledger.pending[purchaseId]
		if pending then
			ledger.pending[purchaseId] = nil
			grant(pending.key, pending.arg)
		end
		return "Granted"
	end
	inFlight[purchaseId] = true
	ledger.seen[purchaseId] = true
	ledger.pending[purchaseId] = { key = key, arg = arg }
	table.insert(ledger.order, purchaseId)
	local ok, saved = pcall(save)
	if not ok or not saved then
		rollback(ledger, purchaseId)
		inFlight[purchaseId] = nil
		return "NotProcessedYet"
	end
	ledger.pending[purchaseId] = nil
	grant(key, arg)
	trim(ledger)
	inFlight[purchaseId] = nil
	return "Granted"
end

export type GrowProfile = {
	planted: { [string]: Economy.PlantRecord },
	water: { channel: boolean, sprinkler: boolean, pond: boolean },
	growthBoostEndsAt: number,
}

-- Finishes the still-growing plant with this uid and returns its tile key. Returns nil if that
-- plant is gone or already grown; it never picks a different plant.
function Core.instantGrow(p: GrowProfile, uid: string?, now: number): string?
	if not uid then
		return nil
	end
	local mult = Economy.growthMultiplier(p, now)
	for key, rec in p.planted do
		if rec.uid == uid then
			if Economy.isGrown(rec, now, mult) then
				return nil
			end
			rec.matured = true
			return key
		end
	end
	return nil
end

-- Applies grants left pending by a crash between save and grant. Returns how many.
-- Products that would do nothing for this profile and must not be granted or banked as a
-- credit. Returns the player-facing reason, or nil when the purchase may go ahead.
function Core.refusal(p: { treadmillLevel: number, speedRobuxTier: number?, luckRobuxTier: number? }, key: string): string?
	if key == "TreadmillLevel" and p.treadmillLevel >= Treadmill.MaxLevel then
		return "Your treadmill is already at max level."
	end
	local boost = Boosts.ByKey[key]
	if boost then
		local current = if boost.Track == "Speed" then (p.speedRobuxTier or 0) else (p.luckRobuxTier or 0)
		if current ~= boost.Tier - 1 then
			return if current >= Boosts.MaxTier then `Your {boost.Track} upgrade is already maxed.` else `Buy {boost.Track} upgrades in order.`
		end
	end
	return nil
end

function Core.recover(ledger: Ledger, grant: (key: string, arg: string?) -> ()): number
	local n = 0
	for id, pending in ledger.pending do
		if not inFlight[id] then
			ledger.pending[id] = nil
			grant(pending.key, pending.arg)
			n += 1
		end
	end
	return n
end

return Core
