--!strict
-- 2D sound playback by name from Shared/Sounds. Names with id 0 no-op.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Settings = require(script.Parent.Settings)

local Sfx = {}

local function group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if g and g:IsA("SoundGroup") then
		return g
	end
	local n = Instance.new("SoundGroup")
	n.Name = name
	n.Parent = SoundService
	return n
end

local sfxGroup = group("Sfx")
local musicGroup = group("Music")
local cache: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}

function Sfx.play(name: string)
	local uri = Sounds.uri(name)
	if not uri then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < 0.08 then
		return
	end
	lastPlayed[name] = now
	local s = cache[name]
	if not s then
		local snd = Instance.new("Sound")
		snd.Name = name
		snd.SoundId = uri
		snd.SoundGroup = sfxGroup
		snd.Parent = sfxGroup
		cache[name] = snd
		s = snd
	end
	s.TimePosition = 0
	s:Play()
end

function Sfx.start()
	local music: Sound? = nil
	local uri = Sounds.uri("Music")
	if uri then
		local m = Instance.new("Sound")
		m.Name = "Music"
		m.SoundId = uri
		m.Looped = true
		m.SoundGroup = musicGroup
		m.Parent = musicGroup
		m:Play()
		music = m
	end
	Settings.onChanged(function(v)
		sfxGroup.Volume = v.sfx
		musicGroup.Volume = v.music
		if music then
			music.Playing = v.music > 0
		end
	end)
end

return Sfx
