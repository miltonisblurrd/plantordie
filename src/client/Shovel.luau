--!strict
-- Shovel: digging with the equipped tool (click or tap), the swing tween, discovery VFX from
-- the server's DigResult, and the shovel upgrade panel. The client only picks the nearest
-- spot and asks; the server validates and rolls (A6).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)

local Shovel = {}

local player = Players.LocalPlayer
local lastSwing = 0

local function nearestSpot(root: BasePart): Model?
	local world = workspace:FindFirstChild("World")
	local biomes = world and world:FindFirstChild("Biomes")
	if not biomes then
		return nil
	end
	local best: Model? = nil
	local bestD = Config.Dig.Range
	for _, biome in biomes:GetChildren() do
		local folder = biome:FindFirstChild("DigSpots")
		if folder then
			for _, spot in folder:GetChildren() do
				if spot:IsA("Model") and spot:GetAttribute("Available") == true and spot.PrimaryPart then
					local d = (spot.PrimaryPart.Position - root.Position).Magnitude
					if d < bestD then
						best, bestD = spot, d
					end
				end
			end
		end
	end
	return best
end

local function swing(tool: Tool)
	local base = CFrame.new(0, -1.2, 0)
	local down = TweenService:Create(tool, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Grip = base * CFrame.Angles(math.rad(-80), 0, 0) })
	local up = TweenService:Create(tool, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Grip = base })
	down.Completed:Once(function()
		up:Play()
	end)
	down:Play()
end

local function onActivated(tool: Tool)
	local snap = State.snapshot
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not snap or not root then
		return
	end
	local shovel = Upgrades.Shovels[snap.shovelTier] or Upgrades.Shovels[1]
	local now = os.clock()
	if now - lastSwing < shovel.DigSeconds then
		return
	end
	local spot = nearestSpot(root)
	if not spot then
		Notifications.show("No dig spot in reach. Find a mound or glowing marker in a biome.", "info", 2)
		return
	end
	local required = spot:GetAttribute("RequiredTier") :: number? or 1
	if shovel.ToughTier < required then
		Notifications.show(`Tough soil! You need a tier {required} shovel.`, "warn")
		return
	end
	lastSwing = now
	swing(tool)
	State.remote("Dig"):FireServer(spot:GetAttribute("SpotId"))
end

local function hookTool(inst: Instance)
	if inst:IsA("Tool") and inst.Name == "Shovel" and not inst:GetAttribute("Hooked") then
		inst:SetAttribute("Hooked", true)
		inst.Activated:Connect(function()
			onActivated(inst)
		end)
	end
end

local function discovery(position: Vector3, species: string, rarityId: string)
	local def = Plants.ById[species]
	local rarity = Rarities.ById[rarityId]
	local color = if rarity then rarity.Color else Color3.new(1, 1, 1)
	local anchor = Instance.new("Part")
	anchor.Name = "DigFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(0, 2, 0)
	anchor.Parent = workspace

	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(color)
	burst.LightEmission = 0.6
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Speed = NumberRange.new(10, 18)
	burst.SpreadAngle = Vector2.new(60, 60)
	burst.Lifetime = NumberRange.new(0.6, 1)
	burst.Acceleration = Vector3.new(0, -20, 0)
	burst.Rate = 0
	burst.Parent = anchor
	local order = if rarity then rarity.Order else 1
	burst:Emit(16 + order * 8)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 50)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = `+1 {if def then def.Name else species} ({rarityId})`
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(1.6), { StudsOffset = Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	local sound = Instance.new("Sound")
	sound.SoundId = Config.Sounds.DigFind
	sound.Volume = 0.7
	sound.Parent = anchor
	sound:Play()
	Debris:AddItem(anchor, 2)

	if order >= 5 then
		Notifications.show(`{rarityId} find! {if def then def.Name else species} is in your bag. Bank it before a guardian catches you!`, "warn")
	end
end

local function buildPanel(bar: Frame)
	local gui = Ui.screen("ShovelPanel", player:WaitForChild("PlayerGui"), 4)
	local p = Ui.panel("Panel", UDim2.fromOffset(340, 200), gui)
	p.AnchorPoint = Vector2.new(0.5, 1)
	p.Position = UDim2.new(0.5, 0, 1, -76)
	p.Visible = false
	local title = Ui.label("Title", "Shovel", true, p)
	title.Size = UDim2.new(1, -24, 0, 34)
	title.Position = UDim2.fromOffset(12, 8)
	local info = Ui.label("Info", "", false, p)
	info.Size = UDim2.new(1, -24, 0, 90)
	info.Position = UDim2.fromOffset(12, 46)
	info.TextWrapped = true
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextYAlignment = Enum.TextYAlignment.Top
	local buy = Ui.button("BuyShovel", "Upgrade Shovel", p)
	buy.Size = UDim2.new(1, -24, 0, Ui.MinTouch)
	buy.Position = UDim2.new(0, 12, 1, -(Ui.MinTouch + 12))

	local open = Ui.button("Shovel", "Shovel", bar)
	open.LayoutOrder = 3
	open.Size = UDim2.fromOffset(110, Ui.MinTouch + 4)
	open.Activated:Connect(function()
		p.Visible = not p.Visible
	end)

	local function stats(s: Upgrades.Shovel): string
		return `{s.DigSeconds}s dig, +{math.floor(s.LuckBonus * 100)}% luck, tough soil tier {s.ToughTier}`
	end

	buy.Activated:Connect(function()
		local snap = State.snapshot
		if not snap then
			return
		end
		local nextDef = Upgrades.Shovels[snap.shovelTier + 1]
		if not nextDef then
			Notifications.show("Your shovel is already max tier.", "info")
			return
		end
		if snap.money < nextDef.Cost then
			Notifications.show(`Not enough money. {nextDef.Name} costs {Format.money(nextDef.Cost)}.`, "error")
			return
		end
		Ui.confirm(`Buy {nextDef.Name}?`, `{stats(nextDef)}.\nPrice: {Format.money(nextDef.Cost)}`, `Buy {Format.money(nextDef.Cost)}`, function()
			State.remote("BuyShovel"):FireServer()
		end)
	end)

	State.onSnapshot(function(s)
		local cur = Upgrades.Shovels[s.shovelTier] or Upgrades.Shovels[1]
		local nextDef = Upgrades.Shovels[s.shovelTier + 1]
		info.Text = `{cur.Name}: {stats(cur)}`
			.. (if nextDef then `\nNext: {nextDef.Name} ({Format.money(nextDef.Cost)})\n{stats(nextDef)}` else "\nMax tier reached.")
		buy.Visible = nextDef ~= nil
	end)
end

function Shovel.start(bar: Frame)
	buildPanel(bar)
	local function watch(container: Instance)
		for _, c in container:GetChildren() do
			hookTool(c)
		end
		container.ChildAdded:Connect(hookTool)
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
	State.remote("DigResult").OnClientEvent:Connect(discovery)
end

return Shovel
