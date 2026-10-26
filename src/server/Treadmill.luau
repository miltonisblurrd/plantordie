--!strict
-- Personal treadmill: standing on your own belt earns speed every tick; speed sets WalkSpeed.
-- The client never sends amounts. Training ticks update the profile quietly and send SpeedGain
-- (amount, belt position, new total) instead of a full StateSync every second.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Speed = require(ReplicatedStorage.Shared.Speed)
local TreadmillData = require(ReplicatedStorage.Shared.Treadmill)
local Boosts = require(ReplicatedStorage.Shared.RobuxBoosts)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)

local Treadmill = {}

local charConns: { [Player]: RBXScriptConnection } = {}

local function humanoidOf(player: Player): (Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if hum and root and root:IsA("BasePart") then
		return hum, root
	end
	return nil, nil
end

-- Every WalkSpeed write goes through applyWalkSpeed: speed stat x scale (carrying), 0 while stunned.
local speedScale: (Player) -> number = function(_player: Player)
	return 1
end
local stunnedUntil: { [Player]: number } = {}
local savedJump: { [Player]: { power: number, height: number } } = {}

function Treadmill.setSpeedScale(fn: (Player) -> number)
	speedScale = fn
end

-- Writes WalkSpeed only when it moved by more than WalkSpeedMinDelta.
function Treadmill.applyWalkSpeed(player: Player, force: boolean?)
	local session = Data.get(player)
	local hum = humanoidOf(player)
	if not session or not hum then
		return
	end
	local target = if (stunnedUntil[player] or 0) > os.clock() then 0 else Speed.walkSpeedFor(session.data.speed) * speedScale(player)
	if force or math.abs(hum.WalkSpeed - target) >= Config.Treadmill.WalkSpeedMinDelta then
		hum.WalkSpeed = target
	end
end

-- No walking or jumping for `seconds`; a newer stun extends it.
function Treadmill.stun(player: Player, seconds: number)
	local hum = humanoidOf(player)
	if not hum then
		return
	end
	local untilT = os.clock() + seconds
	if not savedJump[player] then
		savedJump[player] = { power = hum.JumpPower, height = hum.JumpHeight }
	end
	stunnedUntil[player] = untilT
	hum.JumpPower = 0
	hum.JumpHeight = 0
	Treadmill.applyWalkSpeed(player, true)
	task.delay(seconds, function()
		if stunnedUntil[player] ~= untilT then
			return
		end
		stunnedUntil[player] = nil
		local saved = savedJump[player]
		savedJump[player] = nil
		local h = humanoidOf(player)
		if h and saved then
			h.JumpPower = saved.power
			h.JumpHeight = saved.height
		end
		Treadmill.applyWalkSpeed(player, true)
	end)
end

local function onBelt(belt: BasePart, pos: Vector3): boolean
	local rel = belt.CFrame:PointToObjectSpace(pos)
	local half = belt.Size / 2
	local above = rel.Y - half.Y
	return math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and above >= 0 and above <= Config.Treadmill.HeightTolerance
end

local function tick()
	for _, player in Players:GetPlayers() do
		local idx = Plots.plotOf(player)
		local refs = idx and Plots.refs(idx)
		local session = Data.get(player)
		local hum, root = humanoidOf(player)
		if refs and session and hum and root and hum.Health > 0 and onBelt(refs.belt, root.Position) then
			local d = session.data
			local gain = TreadmillData.gain(d.treadmillLevel, d.trails.equipped, d.speedBonus, Boosts.multiplier("Speed", d.speedRobuxTier))
			Data.update(player, function(p)
				p.speed += gain
			end, true)
			Net.fire("SpeedGain", player, gain, refs.belt.Position, d.speed)
			Treadmill.applyWalkSpeed(player)
		end
	end
end

local function upgrade(player: Player)
	local idx = Plots.plotOf(player)
	local session = Data.get(player)
	if not idx or not session then
		Net.notify(player, "You need a garden to own a treadmill.", "warn")
		return
	end
	local level = session.data.treadmillLevel
	local cost = TreadmillData.nextCost(level)
	if not cost then
		Net.notify(player, "Your treadmill is already at max level.", "warn")
		return
	end
	if session.data.money < cost then
		Net.notify(player, `Not enough money. The next level costs {Format.money(cost)}.`, "error")
		return
	end
	Data.update(player, function(p)
		p.money -= cost
		p.treadmillLevel = level + 1
	end)
	Plots.refresh(player)
	Net.notify(player, `Treadmill upgraded to Lv. {level + 1}! +{Format.short(TreadmillData.speedPerSec(level + 1))} speed/s`)
end

function Treadmill.start()
	Net.on("UpgradeTreadmill", {}, upgrade)

	-- Ownership notice for both prompts; the owner's money path runs through the client confirm.
	for i = 1, Config.World.PlotCount do
		local refs = Plots.refs(i)
		if refs then
			for _, name in { "TreadmillMoneyPrompt", "TreadmillRobuxPrompt" } do
				local prompt = refs.treadmillSign:FindFirstChild(name)
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.Triggered:Connect(function(player)
						if not Plots.isOwner(player, i) then
							Net.notify(player, "That treadmill belongs to another garden.", "warn")
						end
					end)
				end
			end
		end
	end

	Data.onLoaded(function(player)
		charConns[player] = player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 5)
			Treadmill.applyWalkSpeed(player, true)
		end)
		if player.Character then
			Treadmill.applyWalkSpeed(player, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		stunnedUntil[player] = nil
		savedJump[player] = nil
		local c = charConns[player]
		if c then
			c:Disconnect()
			charConns[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Treadmill.TickSeconds)
			tick()
		end
	end)
end

return Treadmill
