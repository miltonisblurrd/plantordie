--!strict
-- Player settings, client-only for the session (not saved to the profile).

local Settings = {}

export type Values = {
	music: number, -- 0..1
	sfx: number, -- 0..1
	laneView: boolean, -- false = default follow camera everywhere
	reducedEffects: boolean, -- no particles, sparkles, rainbow cycling or pop tweens
}

Settings.values = {
	music = 0.5,
	sfx = 0.8,
	laneView = true,
	reducedEffects = false,
} :: Values

local listeners: { (Values) -> () } = {}

function Settings.set(key: string, value: any)
	(Settings.values :: any)[key] = value
	for _, cb in listeners do
		task.spawn(cb, Settings.values)
	end
end

-- Calls `cb` now and on every change.
function Settings.onChanged(cb: (Values) -> ())
	table.insert(listeners, cb)
	cb(Settings.values)
end

return Settings
