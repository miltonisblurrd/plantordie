--!strict
-- The only place sound ids live. A number is a Roblox library asset id; a string is a
-- built-in rbxasset path; 0 means "no sound" and playback no-ops.

local Sounds = {}

-- All ids below were checked against the Roblox catalog: audio assets published by Roblox's own
-- library accounts (Roblox, ProSoundEffects, APMOfficial), which play in any experience.
Sounds.Ids = {
	Dig = 9114083394, -- ProSoundEffects "Dirt Dig Dirt Throws From Shovel 2"
	Discover = 9116395089, -- ProSoundEffects "Magic Glows Soft Clusters Of Chiming Hits 4"
	Plant = 9118598470, -- ProSoundEffects "Rock Hit Dirt Impact 16"
	Buy = 127645268874265, -- Roblox "CoinTransfer_01"
	Click = 15675032796, -- Roblox "Roblox_UI_Small_Click"
	Error = 1839997989, -- APMOfficial "Wrong Answer 3"
	NightWarning = 1845411462, -- APMOfficial "Hollow Gong"
	WaveClear = 1836473422, -- APMOfficial "Victory Fanfare Sting"
	FusionDone = 1837272652, -- APMOfficial "Magic Wand"
	GuardianWarning = 1839909461, -- APMOfficial "Horror Sting"
	Music = 15675069601, -- Roblox "Roblox_UI_Loop_Calm_Music"
	Whoosh = "rbxasset://sounds/swordslash.wav",
	Bonk = "rbxasset://sounds/hit.wav",
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
