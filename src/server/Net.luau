local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(script.Parent.State)

local Net = {}

function Net.setup()
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage

	local function event(name)
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
		return e
	end
	local function func(name)
		local e = Instance.new("RemoteFunction")
		e.Name = name
		e.Parent = folder
		return e
	end

	State.remotes = {
		Action = event("Action"),
		State = event("State"),
		Vfx = event("Vfx"),
		Announce = event("Announce"),
		Roll = func("Roll"),
	}
	return State.remotes
end

function Net.push(player, payload)
	if player and player.Parent then
		State.remotes.State:FireClient(player, payload)
	end
end

function Net.announce(player, text)
	if player and player.Parent then
		State.remotes.Announce:FireClient(player, text)
	end
end

function Net.announceAll(text)
	State.remotes.Announce:FireAllClients(text)
end

function Net.vfx(payload)
	State.remotes.Vfx:FireAllClients(payload)
end

return Net
