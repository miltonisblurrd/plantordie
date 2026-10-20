--!strict
-- Carried seeds. A successful dig reveals a seed on its dirt spot; picking it up (prompt or
-- walking over it) makes you its carrier: one seed at a time, shown above your head, slower
-- WalkSpeed, and the seed's guardian gives chase. Only your own plot banks it into `seeds`.
-- Any drop (DROP button, guardian catch, death, disconnect) leaves it on the ground with a
-- countdown; at 0 it is gone for good. Carried seeds are never saved. State lives in Core;
-- positions only ever come from the server's view of the character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Core = require(script.Core)
local Biomes = require(script.Parent.Biomes)
local Data = require(script.Parent.Data)
local Index = require(script.Parent.Index)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)
local Sync = require(script.Parent.Sync)
local Treadmill = require(script.Parent.Treadmill)

local C = Config.Carry

export type Item = Core.Item
-- reason: pickup/transfer for onPickup; bank/drop/catch/death/leave/transfer for onRelease.
type Hook = (Player, Item, string) -> ()

local Carry = {}

local state = Core.new(C.RevealSeconds, C.DropSeconds)
local models: { [number]: Model } = {}
local countdowns: { [number]: TextLabel } = {}
local heads: { [Player]: BillboardGui } = {}
local lastPos: { [Player]: Vector3 } = {}
local pickupHooks: { Hook } = {}
local releaseHooks: { Hook } = {}
local folder: Instance? = nil

local function fire(list: { Hook }, player: Player, item: Item, reason: string)
	for _, cb in list do
		task.spawn(cb, player, item, reason)
	end
end

function Carry.onPickup(cb: Hook)
	table.insert(pickupHooks, cb)
end

function Carry.onRelease(cb: Hook)
	table.insert(releaseHooks, cb)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and hum and hum.Health > 0 then
		return root
	end
	return nil
end

local function nameOf(species: string): string
	local def = Plants.ById[species]
	return if def then def.Name else species
end

local function colorOf(rarity: string): Color3
	local r = Rarities.ById[rarity]
	return if r then r.Color else Color3.new(1, 1, 1)
end

local function seedFolder(): Instance
	local f = folder
	if f and f.Parent then
		return f
	end
	local n = Instance.new("Folder")
	n.Name = "Seeds"
	n.Parent = workspace
	folder = n
	return n
end

-- Ground point below `pos`, ignoring characters and other seeds.
function Carry.groundAt(pos: Vector3, exclude: Instance?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { seedFolder() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	if exclude then
		table.insert(ignore, exclude)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -80, 0), params)
	local y = if hit then hit.Position.Y else Config.World.GroundY
	return Vector3.new(pos.X, y + 0.8, pos.Z)
end

local function label(parent: Instance, text: string, color: Color3, stroke: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = stroke
	s.Color = Color3.new(0, 0, 0)
	s.Parent = l
	l.Parent = parent
	return l
end

local function billboard(name: string, adornee: BasePart, size: UDim2, offsetY: number): BillboardGui
	local b = Instance.new("BillboardGui")
	b.Name = name
	b.Adornee = adornee
	b.Size = size
	b.StudsOffset = Vector3.new(0, offsetY, 0)
	b.MaxDistance = 120
	b.LightInfluence = 0
	b.Parent = adornee
	return b
end

local function removeModel(id: number)
	local m = models[id]
	if m then
		m:Destroy()
	end
	models[id] = nil
	countdowns[id] = nil
end

local tryPickup: (Player, number) -> ()

local function buildModel(item: Item)
	removeModel(item.id)
	local pos = item.pos
	if not pos then
		return
	end
	local color = colorOf(item.rarity)
	local m = Instance.new("Model")
	m.Name = `Seed_{item.id}`
	local seed = Instance.new("Part")
	seed.Name = "Seed"
	seed.Shape = Enum.PartType.Ball
	seed.Size = Vector3.new(1.4, 1.4, 1.4)
	seed.Material = Enum.Material.Neon
	seed.Color = color
	seed.Anchored = true
	seed.CanCollide = false
	seed.CanTouch = false
	seed.CFrame = CFrame.new(pos)
	seed.Parent = m
	m.PrimaryPart = seed
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Brightness = 2
	light.Parent = seed
	label(billboard("Name", seed, UDim2.fromOffset(180, 30), 1.8), nameOf(item.species), color, 2)
	if item.state == "dropped" then
		countdowns[item.id] = label(billboard("Countdown", seed, UDim2.fromOffset(110, 80), 4.4), tostring(C.DropSeconds), Color3.new(1, 1, 1), 3)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = nameOf(item.species)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = C.PickupRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = seed
	local id = item.id
	prompt.Triggered:Connect(function(player)
		tryPickup(player, id)
	end)
	m.Parent = seedFolder()
	models[id] = m
end

local function setHead(player: Player, item: Item?)
	local old = heads[player]
	if old then
		old:Destroy()
		heads[player] = nil
	end
	local character = player.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not item or not (head and head:IsA("BasePart")) then
		return
	end
	local b = billboard("CarriedSeed", head, UDim2.fromOffset(200, 34), 2.6)
	label(b, `🌱 {nameOf(item.species)}`, colorOf(item.rarity), 2)
	heads[player] = b
end

local function refresh(player: Player)
	Treadmill.applyWalkSpeed(player, true)
	Sync.push(player)
end

function Carry.isCarrying(player: Player): boolean
	return Core.carried(state, player) ~= nil
end

function Carry.carried(player: Player): Item?
	return Core.carried(state, player)
end

-- Snapshot block for the HUD, or nil when empty-handed.
function Carry.snapshotOf(player: Player): { [string]: any }?
	local item = Core.carried(state, player)
	if not item then
		return nil
	end
	return { species = item.species, name = nameOf(item.species), rarity = item.rarity, origin = item.origin }
end

-- Puts a freshly dug seed on the ground at `pos`; only `owner` can take it.
function Carry.reveal(owner: Player, species: string, rarity: string, origin: string, pos: Vector3, exclude: Instance?): Item
	local item = Core.reveal(state, owner, species, rarity, origin, Carry.groundAt(pos, exclude), os.clock())
	buildModel(item)
	return item
end

tryPickup = function(player: Player, id: number)
	local root = rootOf(player)
	local item = state.items[id]
	if not root or not item or not item.pos or (root.Position - item.pos).Magnitude > C.PickupRange + 2 then
		return
	end
	local got, why = Core.pickup(state, player, id, os.clock())
	if not got then
		if why == "not yours" then
			Net.notify(player, "That seed belongs to someone else.", "warn")
		elseif why == "already carrying" then
			Net.notify(player, "You can only carry one seed. Bank or drop yours first.", "warn")
		end
		return
	end
	removeModel(id)
	setHead(player, got)
	refresh(player)
	Net.notify(player, `You grabbed {nameOf(got.species)}! Run it home to your plot!`, "warn")
	fire(pickupHooks, player, got, "pickup")
end

-- Drops the carried seed at `pos` (snapped to the ground). A `stealer` may also pick it up for
-- Config.Bat.StealWindow seconds. Returns the dropped item.
function Carry.drop(player: Player, pos: Vector3?, reason: string, stealer: Player?): Item?
	if not Core.carried(state, player) then
		return nil
	end
	local root = rootOf(player)
	local at = pos or (if root then root.Position else nil) or lastPos[player] or Biomes.HubSpawn.Position
	local item = Core.drop(state, player, Carry.groundAt(at), os.clock(), stealer, Config.Bat.StealWindow)
	if not item then
		return nil
	end
	setHead(player, nil)
	buildModel(item)
	if player.Parent then
		refresh(player)
	end
	fire(releaseHooks, player, item, reason)
	return item
end

-- Moves the carried seed from one player to another in one step. Nil if either side can't.
function Carry.transfer(from: Player, to: Player): Item?
	local item = Core.transfer(state, from, to)
	if not item then
		return nil
	end
	setHead(from, nil)
	setHead(to, item)
	refresh(from)
	refresh(to)
	fire(releaseHooks, from, item, "transfer")
	fire(pickupHooks, to, item, "transfer")
	return item
end

local function bank(player: Player)
	if not Data.get(player) then
		return
	end
	local item = Core.bank(state, player)
	if not item then
		return
	end
	Data.update(player, function(p)
		p.seeds[item.species] = (p.seeds[item.species] or 0) + 1
		Index.record(p, item.species)
	end)
	setHead(player, nil)
	Treadmill.applyWalkSpeed(player, true)
	Net.notify(player, `Secured {nameOf(item.species)}! It's in your seeds.`)
	fire(releaseHooks, player, item, "bank")
end

local function tick()
	local now = os.clock()
	for _, item in Core.expire(state, now) do
		removeModel(item.id)
	end
	for id, l in countdowns do
		local item = state.items[id]
		if item then
			local left = math.max(0, math.ceil(item.expiresAt - now))
			l.Text = tostring(left)
			l.TextColor3 = if left < 5 then Color3.fromHex("#FF2B2B") else Color3.new(1, 1, 1)
		end
	end
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			local pos = root.Position
			lastPos[player] = pos
			if Core.carried(state, player) then
				local idx = Plots.plotAt(pos)
				if idx and idx == Plots.plotOf(player) then
					bank(player)
				end
			else
				for id, item in state.items do
					if item.pos and state.canTake(item, player, now) and (item.pos - pos).Magnitude <= C.TouchRange then
						tryPickup(player, id)
						break
					end
				end
			end
		end
	end
end

local function watchCharacter(player: Player, character: Model)
	local hum = character:WaitForChild("Humanoid", 10)
	if hum and hum:IsA("Humanoid") then
		hum.Died:Connect(function()
			local root = character:FindFirstChild("HumanoidRootPart")
			Carry.drop(player, if root and root:IsA("BasePart") then root.Position else nil, "death")
		end)
	end
end

function Carry.start()
	Treadmill.setSpeedScale(function(player)
		return if Core.carried(state, player) then C.SpeedFactor else 1
	end)
	Sync.setCarryProvider(Carry.snapshotOf)
	Net.on("DropSeed", {}, function(player)
		if Carry.drop(player, nil, "drop") then
			Net.notify(player, `You dropped your seed. Pick it up within {C.DropSeconds}s!`, "warn")
		end
	end)
	local function added(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(watchCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		added(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		Carry.drop(player, lastPos[player], "leave")
		lastPos[player] = nil
		heads[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(C.CheckSeconds)
			tick()
		end
	end)
end

return Carry
