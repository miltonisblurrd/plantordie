--!strict
-- The only place sound ids live. A number is a Roblox library asset id; a string is a
-- built-in rbxasset path; 0 means "no sound yet" and playback no-ops.

local Sounds = {}

Sounds.Ids = {
	Dig = "rbxasset://sounds/clickfast.wav",
	Discover = "rbxasset://sounds/button.wav",
	Plant = 0,
	Buy = 0,
	Error = 0,
	NightWarning = 0,
	WaveClear = 0,
	FusionDone = 0,
	GuardianWarning = "rbxasset://sounds/electronicpingshort.wav",
	Music = 0,
} :: { [string]: number | string }

-- Content URI for a sound name, or nil when the id is 0 or unknown.
function Sounds.uri(name: string): string?
	local id = Sounds.Ids[name]
	if type(id) == "number" then
		return if id > 0 then `rbxassetid://{id}` else nil
	elseif type(id) == "string" and id ~= "" then
		return id
	end
	return nil
end

return Sounds
