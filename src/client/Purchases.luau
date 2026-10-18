--!strict
-- Robux product offers. Always a confirm first (exact benefit from config, and that Roblox shows
-- the price), then PromptProductPurchase. Products with Id 0 are never prompted.
-- PromptProductPurchaseFinished only drives a toast: grants happen solely in the server's
-- ProcessReceipt, so a cancelled or failed prompt grants nothing.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage.Shared.Products)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)

local Purchases = {}

local TITLES: { [string]: string } = {
	InstantGrow = "Instant Grow",
	NeonSkip = "Skip Neon Fusion",
	MegaSkip = "Skip Mega Fusion",
	GrowthBoost = "2x Growth Boost",
	HalloweenPack = "Halloween Seed Pack",
}

function Purchases.title(key: string): string
	return TITLES[key] or key
end

function Purchases.enabled(key: string): boolean
	return Products.enabled(key)
end

-- `arg` is a target hint for the server (InstantGrow: tile key).
function Purchases.offer(key: string, arg: string?)
	local prod = Products.ByKey[key]
	if not prod then
		return
	end
	if prod.Id == 0 then
		Notifications.show("Robux purchases aren't set up in this build yet.", "warn")
		return
	end
	Ui.confirm(
		`Buy {Purchases.title(key)}?`,
		`{prod.Benefit}\nRoblox shows the Robux price in the next step.`,
		"Continue",
		function()
			State.remote("PurchaseIntent"):FireServer(key, arg)
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, prod.Id)
		end
	)
end

function Purchases.start()
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, purchased: boolean)
		if userId ~= Players.LocalPlayer.UserId or not Products.ById[productId] then
			return
		end
		if not purchased then
			Notifications.show("Purchase cancelled. Nothing was charged or granted.", "info")
		end
	end)
end

return Purchases
