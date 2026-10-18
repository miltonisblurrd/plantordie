local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shop = require(game.ReplicatedStorage.Shared.Shop)
local PlantData = require(game.ReplicatedStorage.Shared.PlantData)
local State = require(script.Parent.State)
local ProfileUtil = require(script.Parent.ProfileUtil)
local PlayerActions = require(script.Parent.PlayerActions)
local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)

local ReceiptService = {}

local function weekPlant()
	local index = (math.floor(os.time() / (60 * 60 * 24 * 7)) % #Shop.Weekly) + 1
	return Shop.Weekly[index]
end

local function grantPlant(profile, id, count)
	for _ = 1, count do
		ProfileUtil.addPlant(profile, id)
	end
end

function ReceiptService.currentWeekName()
	local def = PlantData.Plants[weekPlant()]
	return def and def.name or "Weekly plant"
end

local function grant(profile, productKey)
	if productKey == "Gems" then
		profile.gems = (profile.gems or 0) + 80
		return true
	elseif productKey == "InstantGrow" then
		local plant = ProfileUtil.findPlant(profile, profile.pendingGrow)
		if not plant then
			for _, candidate in profile.plants do
				if (candidate.growLeft or 0) > 0 then
					plant = candidate
					break
				end
			end
		end
		if not plant then
			return false
		end
		plant.growLeft = 0
		profile.pendingGrow = nil
		if profile.quest == 3 then
			profile.quest = 4
		end
		return true
	elseif productKey == "InstantRevive" then
		local plant = ProfileUtil.findPlant(profile, profile.pendingRevive)
		if not plant then
			for _, candidate in profile.plants do
				if (candidate.stunnedUntil or 0) > os.time() then
					plant = candidate
					break
				end
			end
		end
		if not plant then
			return false
		end
		local def = PlantData.Plants[plant.id]
		plant.stunnedUntil = 0
		plant.hp = def and def.health or 40
		profile.pendingRevive = nil
		return true
	elseif productKey == "Weekly1" or productKey == "Weekly3" or productKey == "Weekly10" then
		local count = productKey == "Weekly10" and 10 or (productKey == "Weekly3" and 3 or 1)
		grantPlant(profile, weekPlant(), count)
		return true
	elseif productKey == "PaidRoll" then
		return true
	end
	return false
end

function ReceiptService.applyPasses(player)
	local profile = State.profiles[player]
	if not profile then
		return
	end
	local function owns(id)
		if not id or id == 0 then
			return false
		end
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		return ok and result == true
	end
	if owns(Shop.Ids.PassCoins) then
		profile.doubleCoins = true
	end
	if owns(Shop.Ids.PassLuck) then
		profile.extraLuck = true
	end
	if owns(Shop.Ids.PassExclusive) and not profile.hasExclusive then
		profile.hasExclusive = true
		ProfileUtil.addPlant(profile, "CrownFern")
		Net.announce(player, "Crown Fern unlocked.")
	end
end

function ReceiptService.paidRoll(player)
	local profile = State.profiles[player]
	if not profile then
		return false
	end
	local before = #profile.plants
	local costBackup = profile.coins
	profile.coins += 100
	PlayerActions.roll(player)
	if #profile.plants == before then
		profile.coins = costBackup
		return false
	end
	profile.coins = costBackup
	return true
end

function ReceiptService.start()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local profile = State.profiles[player]
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local productKey = nil
		for key, id in Shop.Ids do
			if id == receiptInfo.ProductId and key ~= "PassCoins" and key ~= "PassLuck" and key ~= "PassExclusive" then
				productKey = key
				break
			end
		end
		if not productKey then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok = false
		if productKey == "PaidRoll" then
			ok = ReceiptService.paidRoll(player)
		else
			ok = grant(profile, productKey)
		end
		if not ok then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		PlayerActions.push(player)
		DataService.save(player)
		Net.announce(player, "Purchase granted.")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return ReceiptService
