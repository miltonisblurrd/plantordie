--!strict
-- Permanent discoveries and index rewards. `Index.record` runs inside Data.update callbacks on
-- every path that gives a seed or plant; the server is the only writer of `collection`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Discovery = require(ReplicatedStorage.Shared.Discovery)
local Format = require(ReplicatedStorage.Shared.Format)
local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)

local Index = {}

Index.record = Discovery.record

-- Per session: completion toasts already shown (complete-but-unclaimed ones re-toast once per join).
local notified: { [Player]: { [string]: boolean } } = {}

local function checkComplete(player: Player, session: Data.Session)
	local seen = notified[player]
	if not seen then
		seen = {}
		notified[player] = seen
	end
	local d = session.data
	for _, b in Biomes.List do
		if not seen[b.Id] and not d.indexClaimed[b.Id] and IndexRewards.isComplete(d.collection, b.Id) then
			seen[b.Id] = true
			Net.notify(player, `{b.Emoji} {b.Name} Index complete! Claim your rewards`)
		end
	end
end

local function claim(player: Player, biomeId: string)
	local biome = Biomes.ById[biomeId]
	if not biome or not Data.get(player) then
		return
	end
	local reward: IndexRewards.Reward? = nil
	local why: string? = nil
	Data.update(player, function(p)
		reward, why = IndexRewards.claim(p, biomeId)
	end)
	local r = reward
	if not r then
		Net.notify(player, why or "Can't claim that.", "warn")
		return
	end
	local skin = IndexRewards.SkinById[r.Skin]
	Net.notify(
		player,
		`{biome.Name} Index claimed! +{Format.money(r.Cash)}, +{math.round(r.SpeedBonus * 100)}% Speed forever, {if skin then skin.Name else r.Skin} unlocked`
	)
end

function Index.start()
	Net.on("ClaimIndex", { "string" }, claim)
	Data.onLoaded(function(player, session)
		Discovery.fold(session.data :: any)
		checkComplete(player, session)
	end)
	Data.onChanged(checkComplete)
	Players.PlayerRemoving:Connect(function(player)
		notified[player] = nil
	end)
end

return Index
