--!strict
-- Limited-time event manager (spec §12). Reads Shared.Events, so a future event is one more
-- table entry plus a decor builder under World/Builders/Events.
--   * Active window: decor + purple fog in the hub; seasonal shop and pumpkin dig open.
--   * Inactive: decor and fog removed, shop and dig refuse. Owned seeds/plants are untouched.
--   * Currency: pumpkin dig (cooldown) and surviving nights; quests pay extra once each.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(ReplicatedStorage.Shared.Events)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Data = require(script.Parent.Data)
local Defense = require(script.Parent.Defense)
local Fusion = require(script.Parent.Fusion)
local GuardianAI = require(script.Parent.GuardianAI)
local Net = require(script.Parent.Net)
local Sync = require(script.Parent.Sync)

local Event = {}

local rng = Random.new()
local current: Events.Event? = nil
local decor: Model? = nil
local worldFolder: Instance? = nil
local savedFog: { color: Color3, startD: number, endD: number }? = nil
local digReadyAt: { [Player]: number } = {}

function Event.current(): Events.Event?
	return current
end

local function currencyOf(profile: Data.Profile, e: Events.Event): number
	return profile.event.currency[e.Currency] or 0
end

-- Adds progress to every quest of `stat` and pays newly completed ones. Call inside Data.update.
local function progress(p: Data.Profile, e: Events.Event, stat: string, n: number): { string }
	local done = {}
	for _, q in e.Quests do
		if q.Stat == stat then
			local key = Events.questKey(e.Id, q.Id)
			if not p.event.questsDone[key] then
				local v = math.min(q.Goal, (p.event.quests[key] or 0) + n)
				p.event.quests[key] = v
				if v >= q.Goal then
					p.event.questsDone[key] = true
					p.event.currency[e.Currency] = (p.event.currency[e.Currency] or 0) + q.Reward
					table.insert(done, `Quest complete: {q.Name}! +{q.Reward} {e.Currency}`)
				end
			end
		end
	end
	return done
end

local function award(player: Player, amount: number, stat: string, why: string)
	local e = current
	if not e then
		return
	end
	local msgs: { string } = {}
	Data.update(player, function(p)
		p.event.currency[e.Currency] = (p.event.currency[e.Currency] or 0) + amount
		msgs = progress(p, e, stat, 1)
	end)
	Net.notify(player, `+{amount} {e.Currency} ({why})`)
	for _, m in msgs do
		Net.notify(player, m)
	end
end

-- Rolls `seeds` species from an event pack into the profile. Server RNG only; no yields.
function Event.grantPack(p: Data.Profile, e: Events.Event): { string }
	local got = {}
	for _ = 1, e.Pack.Seeds do
		local species = Events.roll(e.Pack, rng:NextNumber())
		p.seeds[species] = (p.seeds[species] or 0) + 1
		table.insert(got, species)
	end
	return got
end

function Event.packNames(got: { string }): string
	local names = {}
	for _, id in got do
		table.insert(names, if Plants.ById[id] then Plants.ById[id].Name else id)
	end
	return table.concat(names, ", ")
end

local function buyPack(player: Player, eventId: string)
	local session = Data.get(player)
	local e = current
	if not session then
		return
	end
	if not e or e.Id ~= eventId or os.time() > e.EndsAt then
		Net.notify(player, "That event has ended. The shop is closed, but your plants stay.", "warn")
		return
	end
	if currencyOf(session.data, e) < e.Pack.Cost then
		Net.notify(player, `Not enough {e.Currency}. {e.Pack.Name} costs {e.Pack.Cost}.`, "error")
		return
	end
	local got: { string } = {}
	Data.update(player, function(p)
		p.event.currency[e.Currency] -= e.Pack.Cost
		got = Event.grantPack(p, e)
	end)
	Net.notify(player, `{e.Pack.Name}: you got {Event.packNames(got)}! Check your seeds.`)
end

local function dig(player: Player)
	local e = current
	if not e or not decor then
		Net.notify(player, "The pumpkin patch is only open during the event.", "warn")
		return
	end
	local patch = decor:FindFirstChild("PumpkinPatch") :: BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not patch or not root or (root.Position - patch.Position).Magnitude > Config.Event.DigRange + 4 then
		Net.notify(player, "Stand in the pumpkin patch to dig.", "warn")
		return
	end
	local now = os.clock()
	if (digReadyAt[player] or 0) > now then
		Net.notify(player, `The patch needs {math.ceil(digReadyAt[player] - now)}s to refill.`, "warn")
		return
	end
	digReadyAt[player] = now + e.DigCooldown
	award(player, e.DigReward, "dig", "pumpkin patch")
end

local function setFog(on: boolean)
	if on and not savedFog then
		savedFog = { color = Lighting.FogColor, startD = Lighting.FogStart, endD = Lighting.FogEnd }
		Lighting.FogColor = Config.Event.FogColor
		Lighting.FogStart = Config.Event.FogStart
		Lighting.FogEnd = Config.Event.FogEnd
	elseif not on and savedFog then
		Lighting.FogColor = savedFog.color
		Lighting.FogStart = savedFog.startD
		Lighting.FogEnd = savedFog.endD
		savedFog = nil
	end
end

local function apply(e: Events.Event?)
	if decor then
		decor:Destroy()
		decor = nil
	end
	if e and worldFolder then
		local builders = script.Parent.World.Builders.Events
		local mod = builders:FindFirstChild(e.Decor)
		if mod and mod:IsA("ModuleScript") then
			decor = (require(mod) :: any).build(worldFolder)
		end
	end
	setFog(e ~= nil)
	GuardianAI.setEventGuardian(if e and e.Guardian then e.Id else nil)
	ReplicatedStorage:SetAttribute("ActiveEvent", if e then e.Id else nil)
	for _, player in Players:GetPlayers() do
		Sync.push(player)
	end
end

local function check()
	local e = Events.active(os.time())
	local changed = (e and e.Id) ~= (current and current.Id)
	if changed then
		current = e
		apply(e)
		if e then
			print(`[Event] {e.Name} active until {e.EndsAt}`)
		end
	end
end

-- HUD block for Sync: nil when no event is running.
local function hudFor(player: Player): { [string]: any }?
	local e = current
	local session = Data.get(player)
	if not e or not session then
		return nil
	end
	local d = session.data
	local quests = {}
	for _, q in e.Quests do
		local key = Events.questKey(e.Id, q.Id)
		table.insert(quests, { name = q.Name, progress = d.event.quests[key] or 0, goal = q.Goal, reward = q.Reward, done = d.event.questsDone[key] == true })
	end
	return {
		id = e.Id,
		name = e.Name,
		endsAt = e.EndsAt,
		currency = e.Currency,
		amount = currencyOf(d, e),
		packName = e.Pack.Name,
		packCost = e.Pack.Cost,
		packProduct = e.Pack.Product,
		quests = quests,
	}
end

function Event.start(world: Instance)
	worldFolder = world
	Sync.setEventProvider(hudFor)
	Net.on("EventBuyPack", { "string" }, buyPack)
	Net.on("EventDig", {}, dig)
	Defense.onNightSurvived(function(player)
		local e = current
		if e then
			award(player, e.CurrencyPerNight, "nights", "night survived")
		end
	end)
	Fusion.onClaimed(function(player)
		local e = current
		if not e then
			return
		end
		local msgs: { string } = {}
		Data.update(player, function(p)
			msgs = progress(p, e, "fuse", 1)
		end)
		for _, m in msgs do
			Net.notify(player, m)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		digReadyAt[player] = nil
	end)
	check()
	task.spawn(function()
		while true do
			task.wait(Config.Event.CheckSeconds)
			check()
		end
	end)
end

return Event
