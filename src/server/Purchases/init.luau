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
local Core = require(script.Core)
local Data = require(script.Parent.Data)
local Event = require(script.Parent.Event)
local Fusion = require(script.Parent.Fusion)
local Net = require(script.Parent.Net)

local Purchases = {}

local CREDITABLE: { [string]: boolean } = { InstantGrow = true, NeonSkip = true, MegaSkip = true }
local SKIP_MACHINE: { [string]: string } = { NeonSkip = "Neon", MegaSkip = "Mega" }

-- Last product the client said it is about to buy, with its target (InstantGrow tile key).
-- Only used to pick a target; the receipt decides what is granted.
local intents: { [Player]: { key: string, arg: string? } } = {}

-- Applies a product's effect to the profile. Returns a message, or nil if there was nothing to
-- apply it to (credits only when `bank`). Never yields.
local function apply(p: Data.Profile, key: string, arg: string?, bank: boolean): string?
	local now = os.time()
	if key == "InstantGrow" then
		local mult = Economy.growthMultiplier(p, now)
		local target: string? = nil
		local rec = arg and p.planted[arg]
		if rec and not Economy.isGrown(rec, now, mult) then
			target = arg
		else
			local longest = -1
			for k, r in p.planted do
				if not Economy.isGrown(r, now, mult) then
					local left = (r.plantedAt or now) + Economy.effectiveGrowSeconds(r, mult) - now
					if left > longest then
						longest, target = left, k
					end
				end
			end
		end
		if target then
			local r = p.planted[target]
			r.matured = true
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
	end
	if bank and CREDITABLE[key] then
		p.credits[key] = (p.credits[key] or 0) + 1
		return `Nothing to use {key} on right now, so it was saved. Use it from the panel later.`
	end
	return nil
end

-- The grant the receipt path runs after its ledger write is saved.
local function grant(player: Player, key: string, arg: string?)
	local msg: string? = nil
	Data.update(player, function(p)
		msg = apply(p, key, arg, true)
	end)
	Fusion.refresh(player)
	if msg then
		Net.notify(player, msg)
	end
end

local function run(player: Player, session: Data.Session, purchaseId: string, key: string, arg: string?): string
	local result: string = Core.process(session.data.receiptLedger, purchaseId, key, arg, function()
		return Data.save(session)
	end, function(k, a)
		grant(player, k, a)
	end)
	if result == "Granted" then
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
	local intent = intents[player]
	local arg = if intent and intent.key == product.Key then intent.arg else nil
	local result = run(player, session, tostring(info.PurchaseId), product.Key, arg)
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
	local intent = intents[player]
	local arg = if intent and intent.key == key then intent.arg else nil
	return run(player, session, purchaseId or ("debug-" .. HttpService:GenerateGUID(false)), key, arg)
end

local function useCredit(player: Player, key: string, arg: string?)
	local session = Data.get(player)
	if not session or not CREDITABLE[key] or (session.data.credits[key] or 0) < 1 then
		return
	end
	local msg: string? = nil
	Data.update(player, function(p)
		msg = apply(p, key, arg, false)
		if msg then
			p.credits[key] -= 1
			if p.credits[key] <= 0 then
				p.credits[key] = nil
			end
		end
	end)
	Fusion.refresh(player)
	Net.notify(player, msg or "Nothing to use that on right now. Your credit is kept.", if msg then "info" else "warn")
end

function Purchases.start()
	MarketplaceService.ProcessReceipt = processReceipt
	Net.on("PurchaseIntent", { "string", "string?" }, function(player, key: string, arg: string?)
		if Products.ByKey[key] then
			intents[player] = { key = key, arg = arg }
		end
	end)
	Net.on("UseCredit", { "string", "string?" }, useCredit)
	Players.PlayerRemoving:Connect(function(player)
		intents[player] = nil
	end)
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
		local bf = Instance.new("BindableFunction")
		bf.Name = "DebugGrant"
		bf.OnInvoke = function(player: Player, key: string, purchaseId: string?)
			return Purchases.debugGrant(player, key, purchaseId)
		end
		bf.Parent = ServerStorage
	end
end

return Purchases
