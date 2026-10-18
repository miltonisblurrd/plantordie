--!strict
-- Creates every remote from Shared.Remotes and wraps client->server handlers with
-- type validation, per-player per-remote token-bucket rate limits, and a loaded-profile gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local instances: { [string]: RemoteEvent | RemoteFunction } = {}
for _, def in Remotes.List do
	local r: Instance = if def.Kind == "Function" then Instance.new("RemoteFunction") else Instance.new("RemoteEvent")
	r.Name = def.Name
	r.Parent = folder
	instances[def.Name] = r :: any
end
folder.Parent = ReplicatedStorage

-- Profile gate is injected by Boot to avoid a Net <-> Data require cycle.
local isLoaded: (Player) -> boolean = function(_player: Player)
	return false
end

function Net.setProfileGate(fn: (Player) -> boolean)
	isLoaded = fn
end

type Bucket = { tokens: number, last: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

local function allow(player: Player, name: string): boolean
	local def = Remotes.ByName[name]
	if def.Rate <= 0 then
		return false
	end
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local b = perPlayer[name]
	if not b then
		b = { tokens = def.Burst, last = now }
		perPlayer[name] = b
	end
	b.tokens = math.min(def.Burst, b.tokens + (now - b.last) * def.Rate)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

-- Arg spec entries are typeof() names, optionally suffixed with "?" for optional.
-- "number" also rejects NaN and infinities.
local function validate(spec: { string }, args: { any }, n: number): boolean
	if n > #spec then
		return false
	end
	for i, expected in spec do
		local v = args[i]
		local optional = string.sub(expected, -1) == "?"
		local t = if optional then string.sub(expected, 1, -2) else expected
		if v == nil then
			if not optional then
				return false
			end
		elseif typeof(v) ~= t then
			return false
		elseif t == "number" and (v ~= v or v == math.huge or v == -math.huge) then
			return false
		elseif t == "string" and #v > 200 then
			return false
		end
	end
	return true
end

local function guard(name: string, spec: { string }, player: Player, ...: any): (boolean, { any })
	local n = select("#", ...)
	local args = { ... }
	if not isLoaded(player) then
		return false, args
	end
	if not allow(player, name) then
		return false, args
	end
	if not validate(spec, args, n) then
		return false, args
	end
	return true, args
end

function Net.on(name: string, spec: { string }, handler: (Player, ...any) -> ())
	local r = instances[name]
	assert(r and r:IsA("RemoteEvent"), "Unknown RemoteEvent " .. name)
	r.OnServerEvent:Connect(function(player, ...)
		local ok, args = guard(name, spec, player, ...)
		if ok then
			handler(player, table.unpack(args, 1, #spec))
		end
	end)
end

function Net.onInvoke(name: string, spec: { string }, handler: (Player, ...any) -> ...any)
	local r = instances[name]
	assert(r and r:IsA("RemoteFunction"), "Unknown RemoteFunction " .. name)
	r.OnServerInvoke = function(player, ...)
		local ok, args = guard(name, spec, player, ...)
		if not ok then
			return nil
		end
		return handler(player, table.unpack(args, 1, #spec))
	end
end

function Net.fire(name: string, player: Player, ...: any)
	(instances[name] :: RemoteEvent):FireClient(player, ...)
end

function Net.fireAll(name: string, ...: any)
	(instances[name] :: RemoteEvent):FireAllClients(...)
end

function Net.notify(player: Player, text: string, kind: string?)
	Net.fire("Notify", player, text, kind or "info")
end

return Net
