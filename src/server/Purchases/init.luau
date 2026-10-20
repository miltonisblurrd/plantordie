--!strict
-- Developer Products (spec §14). The only grant path is ProcessReceipt -> Core.process, which
-- saves the PurchaseId to the receipt ledger before any grant. Nothing is granted on the
-- client's PromptProductPurchaseFinished signal, and the client never names a reward.
-- Products with Id 0 never match a receipt and the client never prompts them.
--
-- Studio test hook: ServerStorage.DebugGrant (BindableFunction, Studio only), e.g. in the
-- command bar:  game.ServerStorage.DebugGrant:Invoke(game.Players:GetPlayers()[1], "NeonSkip")
-- Optional third arg reuses a PurchaseId to test idempotency. It runs the receipt path itself.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Events = require(ReplicatedStorage.Shared.Events)
local Format = require(ReplicatedStorage.Shared.Format)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Products = require(ReplicatedStorage.Shared.Products)
local TreadmillData = require(ReplicatedStorage.Shared.Treadmill)
local Core = require(script.Core)
local Data = require(script.Parent.Data)
local Event = require(script.Parent.Event)
local Fusion = require(script.Parent.Fusion)
local Garden = require(script.Parent.Garden)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)

local Purchases = {}

local CREDITABLE: { [string]: boolean } = { InstantGrow = true, NeonSkip = true, MegaSkip = true, TreadmillLevel = true }
local SKIP_MACHINE: { [string]: string } = { NeonSkip = "Neon", MegaSkip = "Mega" }

-- Applies a product's effect to the profile. Returns a message, or nil if there was nothing to
-- apply it to (credits only when `bank`). Never yields. InstantGrow's `arg` is a plant uid; a
-- skip always targets its own machine, so its credit (keyed NeonSkip / MegaSkip) stays bound to
-- that machine.
local function apply(p: Data.Profile, key: string, arg: string?, bank: boolean): string?
	local now = os.time()
	if key == "InstantGrow" then
		local tile = Core.instantGrow(p, arg, now)
		if tile then
			local r = p.planted[tile]
			local def = Plants.ById[r.species]
			return `Instant Grow: {if def then def.Name else r.species} is fully grown!`
		end
	elseif SKIP_MACHINE[key] then
		if Fusion.skip(p, SKIP_MACHINE[key], now) then
			return `{SKIP_MACHINE[key]} fusion finished! Claim it at the machine.`
		end
	elseif key == "GrowthBoost" then
		local prod = Products.ByKey.GrowthBoost
		p.growthBoostEndsAt = math.max(now, p.growthBoostEndsAt) + (prod.Seconds or 1800)
		return `Growth Boost active for {Format.duration(p.growthBoostEndsAt - now)}.`
	elseif key == "HalloweenPack" then
		local e = Events.ById[Products.ByKey.HalloweenPack.Event or ""]
		if e then
			return `{e.Pack.Name}: you got {Event.packNames(Event.grantPack(p, e))}!`
		end
	elseif key == "TreadmillLevel" then
		if p.treadmillLevel < TreadmillData.MaxLevel then
			p.treadmillLevel += 1
			return `Treadmill upgraded to Lv. {p.treadmillLevel}!`
		end
	end
	if bank and CREDITABLE[key] then
		p.credits[key] = (p.credits[key] or 0) + 1
		return `Nothing to use {key} on right now, so it was saved. Use it from the panel later.`
	end
	return nil
end

-- The grant the receipt path runs after its ledger write is saved.
local function grant(player: Player, key: string, arg: string?)
	if key == "Unstun" then
		if arg and Garden.clearStun(player, arg) then
			Net.notify(player, "That plant is awake again.")
		else
			Net.notify(player, "That plant wasn't stunned.", "warn")
		end
		return
	end
	local msg: string? = nil
	Data.update(player, function(p)
		msg = apply(p, key, arg, true)
	end)
	Fusion.refresh(player)
	Plots.refresh(player)
	if msg then
		Net.notify(player, msg)
	end
end

-- The target comes from the saved profile, and Core.process stores it in the pending grant
-- before the save, so a crash-recovered grant hits the same plant.
local function run(player: Player, session: Data.Session, purchaseId: string, key: string): string
	local arg = session.data.purchaseIntent[key]
	local result: string = Core.process(session.data.receiptLedger, purchaseId, key, arg, function()
		return Data.save(session)
	end, function(k, a)
		grant(player, k, a)
	end)
	if result == "Granted" then
		if arg and session.data.purchaseIntent[key] == arg then
			Data.update(player, function(p)
				p.purchaseIntent[key] = nil
			end)
		end
		task.spawn(Data.save, session)
	else
		warn(`[Purchases] {key} {purchaseId} for {player.Name}: ledger save failed; NotProcessedYet, nothing granted`)
	end
	return result
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local product = Products.ById[info.ProductId]
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local session = player and Data.get(player)
	if not product or not player or not session then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local result = run(player, session, tostring(info.PurchaseId), product.Key)
	return if result == "Granted" then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Studio only. Same receipt path (ledger, save, grant) with a synthetic PurchaseId.
function Purchases.debugGrant(player: Player, key: string, purchaseId: string?): string
	if not RunService:IsStudio() then
		return "refused: DebugGrant only runs in Studio"
	end
	if not Products.ByKey[key] then
		return `unknown product {key}`
	end
	local session = Data.get(player)
	if not session then
		return "player has no loaded profile"
	end
	return run(player, session, purchaseId or ("debug-" .. HttpService:GenerateGUID(false)), key)
end

local function useCredit(player: Player, key: string, arg: string?)
	local session = Data.get(player)
	if not session or not CREDITABLE[key] or (session.data.credits[key] or 0) < 1 then
		return
	end
	local target = arg
	if key == "InstantGrow" then
		local rec = arg and session.data.planted[arg]
		target = rec and rec.uid
	end
	local msg: string? = nil
	Data.update(player, function(p)
		msg = apply(p, key, target, false)
		if msg then
			p.credits[key] -= 1
			if p.credits[key] <= 0 then
				p.credits[key] = nil
			end
		end
	end)
	Fusion.refresh(player)
	Plots.refresh(player)
	Net.notify(player, msg or "Nothing to use that on right now. Your credit is kept.", if msg then "info" else "warn")
end

function Purchases.start()
	MarketplaceService.ProcessReceipt = processReceipt
	-- InstantGrow: `arg` is the tile key of one of the player's growing plants; its uid is saved
	-- on the profile. Anything else clears the intent, so a stale target is never reused.
	Net.on("PurchaseIntent", { "string", "string?" }, function(player, key: string, arg: string?)
		if key ~= "InstantGrow" and key ~= "Unstun" then
			return
		end
		if key == "Unstun" then
			Data.update(player, function(p)
				local rec = arg and p.planted[arg]
				p.purchaseIntent.Unstun = if rec then arg else nil
			end)
			return
		end
		Data.update(player, function(p)
			local rec = arg and p.planted[arg]
			local growing = rec ~= nil and not Economy.isGrown(rec, os.time(), Economy.growthMultiplier(p, os.time()))
			local uid: string? = if growing and rec then rec.uid else nil
			p.purchaseIntent.InstantGrow = uid :: any
		end)
	end)
	Net.on("UseCredit", { "string", "string?" }, useCredit)
	Data.onLoaded(function(player, session)
		local n = Core.recover(session.data.receiptLedger, function(k, a)
			grant(player, k, a)
		end)
		if n > 0 then
			warn(`[Purchases] applied {n} pending grant(s) for {player.Name}`)
			Data.save(session)
		end
	end)
	if RunService:IsStudio() then
		Net.on("DebugUnstun", { "string" }, function(player, key: string)
			if Garden.clearStun(player, key) then
				Net.notify(player, "That plant is awake again.")
			end
		end)
		local bf = Instance.new("BindableFunction")
		bf.Name = "DebugGrant"
		bf.OnInvoke = function(player: Player, key: string, purchaseId: string?)
			return Purchases.debugGrant(player, key, purchaseId)
		end
		bf.Parent = ServerStorage
	end
end

return Purchases
