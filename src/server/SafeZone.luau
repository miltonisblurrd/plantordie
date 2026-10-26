--!strict
-- Server authority for the shared Safe Zone. Reads each character's position on the server,
-- keeps the player attribute InSafeZone current and fires onEnter / onLeave on every change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Region = require(ReplicatedStorage.Shared.SafeZone)

type Hook = (Player) -> ()

local SafeZone = {}

SafeZone.contains = Region.contains
SafeZone.keepOut = Region.keepOut
SafeZone.pushOut = Region.pushOut

local inside: { [Player]: boolean } = {}
local enterHooks: { Hook } = {}
local leaveHooks: { Hook } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function SafeZone.onEnter(cb: Hook)
	table.insert(enterHooks, cb)
end

function SafeZone.onLeave(cb: Hook)
	table.insert(leaveHooks, cb)
end

local function set(player: Player, now: boolean)
	if (inside[player] == true) == now then
		return
	end
	inside[player] = now
	player:SetAttribute("InSafeZone", now)
	for _, cb in if now then enterHooks else leaveHooks do
		task.spawn(cb, player)
	end
end

-- Re-reads the position now, so callers never act on a stale flag.
function SafeZone.isProtected(player: Player): boolean
	local root = rootOf(player)
	local now = root ~= nil and Region.contains(root.Position)
	set(player, now)
	return now
end

function SafeZone.start()
	Players.PlayerRemoving:Connect(function(player)
		inside[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.SafeZone.CheckSeconds)
			for _, player in Players:GetPlayers() do
				SafeZone.isProtected(player)
			end
		end
	end)
end

return SafeZone
