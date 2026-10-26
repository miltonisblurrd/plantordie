--!strict
-- Bats: a swing knocks back and stuns the nearest player in front of you. If they carry a seed
-- it drops with the normal countdown and, for Config.Bat.StealWindow seconds, you may grab it
-- too. Nothing else a player owns can move. Only Players' characters are ever targets, and
-- nobody can hit or be hit inside the shared Safe Zone (the hub and every plot).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
local Core = require(script.Core)
local Carry = require(script.Parent.Carry)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local SafeZone = require(script.Parent.SafeZone)
local Tools = require(script.Parent.Tools)
local Treadmill = require(script.Parent.Treadmill)

local B = Config.Bat
local SAFE_NOTIFY_SECONDS = 3

local Bat = {}

local lastSwing: { [Player]: number } = {}
local lastSafeNotify: { [Player]: number } = {}

local function rootOf(player: Player): (BasePart?, boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") then
		return root, hum ~= nil and hum.Health > 0
	end
	return nil, false
end

Bat.inSafeZone = SafeZone.contains

local function lineOfSight(from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local seeds = workspace:FindFirstChild("Seeds")
	if seeds then
		table.insert(ignore, seeds)
	end
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(from, to - from, params) == nil
end

local function holdsBat(player: Player): boolean
	local character = player.Character
	local tool = character and character:FindFirstChild("Bat")
	return tool ~= nil and tool:IsA("Tool")
end

local function hit(attacker: Player, victim: Player, aRoot: BasePart, vRoot: BasePart)
	local vel = Core.knock(aRoot.Position, vRoot.Position, aRoot.CFrame.LookVector, B)
	Treadmill.stun(victim, B.StunSeconds)
	vRoot.AssemblyLinearVelocity = vel
	local at = vRoot.Position
	Net.fire("BatHit", victim, at, vel)
	Net.fire("BatHit", attacker, at, nil)
	if Carry.isCarrying(victim) and Carry.drop(victim, at, "hit", attacker) then
		Net.notify(victim, `{attacker.DisplayName} knocked your seed loose!`, "warn")
	end
end

local function swing(attacker: Player)
	if not holdsBat(attacker) then
		return
	end
	local aRoot, aAlive = rootOf(attacker)
	if not aRoot then
		return
	end
	local now = os.clock()
	local a: Core.Attacker = {
		pos = aRoot.Position,
		look = aRoot.CFrame.LookVector,
		alive = aAlive,
		safe = Bat.inSafeZone(aRoot.Position),
		lastSwing = lastSwing[attacker] or -math.huge,
	}
	local refusal = Core.swingRefusal(a, now, B)
	if refusal == "cooldown" or refusal == "dead" then
		return
	end
	lastSwing[attacker] = now
	if refusal == "safe" then
		if now - (lastSafeNotify[attacker] or -math.huge) >= SAFE_NOTIFY_SECONDS then
			lastSafeNotify[attacker] = now
			Net.notify(attacker, "Safe zone, no fighting", "warn")
		end
		return
	end
	a.lastSwing = -math.huge
	local targets: { Core.Target } = {}
	for _, p in Players:GetPlayers() do
		if p == attacker then
			continue
		end
		local root, alive = rootOf(p)
		if root and (root.Position - a.pos).Magnitude <= B.Range then
			table.insert(targets, {
				key = p,
				pos = root.Position,
				alive = alive,
				safe = Bat.inSafeZone(root.Position),
				los = lineOfSight(a.pos, root.Position),
			})
		end
	end
	local target = Core.pick(a, targets, now, B)
	if not target then
		return
	end
	local victim = target.key :: Player
	local vRoot = rootOf(victim)
	if vRoot then
		hit(attacker, victim, aRoot, vRoot)
	end
end

local function equipSkin(player: Player, id: string)
	local session = Data.get(player)
	local skin = IndexRewards.SkinById[id]
	if not session or not skin then
		return
	end
	if not session.data.batSkins.owned[id] then
		Net.notify(player, "Complete that biome's Index to unlock this bat.", "warn")
		return
	end
	if session.data.batSkins.equipped ~= id then
		Data.update(player, function(p)
			if p.batSkins.owned[id] then
				p.batSkins.equipped = id
			end
		end)
	end
	Tools.giveBat(player)
	Net.notify(player, `Equipped the {skin.Name}.`)
end

function Bat.start()
	Net.on("SwingBat", {}, swing)
	Net.on("EquipBatSkin", { "string" }, equipSkin)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastSafeNotify[player] = nil
	end)
end

return Bat
