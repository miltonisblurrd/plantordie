--!strict
-- Carry state machine, no Roblox calls so the harness can drive it. Carrier keys are opaque
-- (Player in game, strings in the harness). Every transition checks the item's current state,
-- so of two pickups for one seed exactly one succeeds and a seed is never in two places.
--   revealed --pickup--> carried --drop--> dropped --pickup--> carried --bank--> (removed)
--   revealed/dropped --expire--> (removed). transfer moves a carried seed between carriers.

export type ItemState = "revealed" | "carried" | "dropped"
export type Item = {
	id: number,
	species: string,
	rarity: string,
	origin: string, -- biome id (or event id) whose guardian chases the carrier
	owner: any,
	state: ItemState,
	carrier: any?,
	pos: Vector3?, -- nil while carried
	expiresAt: number, -- math.huge while carried
	stealer: any?, -- besides the owner, may pick up a dropped seed until stealUntil
	stealUntil: number,
}
export type State = {
	items: { [number]: Item },
	byCarrier: { [any]: number },
	nextId: number,
	revealSeconds: number,
	dropSeconds: number,
	-- Who may pick a seed up at `now`.
	canTake: (Item, any, number) -> boolean,
}

local Core = {}

local function ownerOrStealer(item: Item, who: any, now: number): boolean
	return item.owner == who or (item.stealer ~= nil and item.stealer == who and now < item.stealUntil)
end

function Core.new(revealSeconds: number, dropSeconds: number): State
	return { items = {}, byCarrier = {}, nextId = 1, revealSeconds = revealSeconds, dropSeconds = dropSeconds, canTake = ownerOrStealer }
end

function Core.reveal(s: State, owner: any, species: string, rarity: string, origin: string, pos: Vector3, now: number): Item
	local item: Item = {
		id = s.nextId, species = species, rarity = rarity, origin = origin, owner = owner,
		state = "revealed", carrier = nil, pos = pos, expiresAt = now + s.revealSeconds, stealer = nil, stealUntil = 0,
	}
	s.nextId += 1
	s.items[item.id] = item
	return item
end

function Core.carried(s: State, who: any): Item?
	local id = s.byCarrier[who]
	return if id then s.items[id] else nil
end

-- A stealer who picks the seed up becomes its owner. Returns the item, or nil and a reason: "gone" | "taken" | "not yours" | "already carrying".
function Core.pickup(s: State, who: any, id: number, now: number): (Item?, string?)
	local item = s.items[id]
	if not item or now >= item.expiresAt then
		return nil, "gone"
	end
	if item.state == "carried" then
		return nil, "taken"
	end
	if not s.canTake(item, who, now) then
		return nil, "not yours"
	end
	if s.byCarrier[who] then
		return nil, "already carrying"
	end
	item.state = "carried"
	item.owner = who
	item.stealer = nil
	item.stealUntil = 0
	item.carrier = who
	item.pos = nil
	item.expiresAt = math.huge
	s.byCarrier[who] = id
	return item, nil
end

-- Every drop restarts the full countdown. `stealer` may also take it for `stealSeconds`.
function Core.drop(s: State, who: any, pos: Vector3, now: number, stealer: any?, stealSeconds: number?): Item?
	local item = Core.carried(s, who)
	if not item then
		return nil
	end
	s.byCarrier[who] = nil
	item.state = "dropped"
	item.carrier = nil
	item.pos = pos
	item.expiresAt = now + s.dropSeconds
	item.stealer = if stealer ~= nil and stealer ~= who then stealer else nil
	item.stealUntil = if item.stealer ~= nil then now + (stealSeconds or 0) else 0
	return item
end

function Core.transfer(s: State, from: any, to: any): Item?
	local item = Core.carried(s, from)
	if not item or from == to or s.byCarrier[to] then
		return nil
	end
	s.byCarrier[from] = nil
	s.byCarrier[to] = item.id
	item.carrier = to
	return item
end

-- Removes the carried seed; the caller credits it.
function Core.bank(s: State, who: any): Item?
	local item = Core.carried(s, who)
	if not item then
		return nil
	end
	s.byCarrier[who] = nil
	s.items[item.id] = nil
	return item
end

function Core.expire(s: State, now: number): { Item }
	local gone = {}
	for id, item in s.items do
		if item.state ~= "carried" and now >= item.expiresAt then
			s.items[id] = nil
			table.insert(gone, item)
		end
	end
	return gone
end

return Core
