--!strict
-- Storage backend. Real DataStore in live servers; in-memory fallback only in Studio without API access.
-- Both backends expose the same UpdateAsync-style transform so the session/lock logic is identical.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Mode = "DataStore" | "Memory" | "Unavailable"

local Store = {}
local mode: Mode = "Unavailable"

function Store.getMode(): Mode
	return mode
end

local dataStore: DataStore? = nil
local memory: { [string]: any } = {}

local function deepCopy<T>(v: T): T
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v :: any do
		out[k] = deepCopy(x)
	end
	return out :: any
end
Store.deepCopy = deepCopy

function Store.init()
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok and RunService:IsStudio() then
		ok = pcall(function()
			(ds :: DataStore):GetAsync("__probe")
		end)
	end
	if ok then
		dataStore = ds
		mode = "DataStore"
	elseif RunService:IsStudio() then
		mode = "Memory"
		warn("[Data] *** Studio has no DataStore API access. Using IN-MEMORY profiles; nothing will persist. ***")
		warn("[Data] Enable Game Settings > Security > 'Enable Studio Access to API Services' to test real saves.")
	else
		mode = "Unavailable"
		warn("[Data] DataStore unavailable; every load will fail safely and players will be kicked without saving.")
	end
end

-- Studio-only fault injection for acceptance check A25: set workspace attribute DebugFailDataStore = true.
local function injectedFailure(): boolean
	return RunService:IsStudio() and workspace:GetAttribute("DebugFailDataStore") == true
end

-- Runs transform like DataStore:UpdateAsync. Errors propagate to the caller (who retries).
-- Returning nil from transform cancels the write.
function Store.update(key: string, transform: (any) -> any): boolean
	if injectedFailure() then
		error("[Data] injected DataStore failure (DebugFailDataStore)")
	end
	if mode == "DataStore" then
		(dataStore :: DataStore):UpdateAsync(key, transform)
	elseif mode == "Memory" then
		local result = transform(deepCopy(memory[key]))
		if result ~= nil then
			memory[key] = deepCopy(result)
		end
	else
		error("[Data] no storage backend")
	end
	return true
end

return Store
