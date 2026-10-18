local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")

local PlantData = require(ReplicatedStorage.Shared.PlantData)
local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Quests = require(ReplicatedStorage.Shared.Quests)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Action = remotes:WaitForChild("Action")
local StateEvent = remotes:WaitForChild("State")
local Vfx = remotes:WaitForChild("Vfx")
local Announce = remotes:WaitForChild("Announce")
local Roll = remotes:WaitForChild("Roll")

local state = nil
local panel = "plants"
local paidRollsHidden = false

local gui = Instance.new("ScreenGui")
gui.Name = "PlantOrDie"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

local function label(parent, text, size, pos, color)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextSize = 16
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Size = size
	t.Position = pos
	t.Parent = parent
	return t
end

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 52)
top.BackgroundColor3 = Color3.fromRGB(16, 22, 16)
top.BackgroundTransparency = 0.15
top.BorderSizePixel = 0
top.Parent = gui
local coinsLabel = label(top, "Coins 0", UDim2.new(0.22, 0, 1, 0), UDim2.new(0, 8, 0, 0), Color3.fromRGB(255, 220, 80))
local lootLabel = label(top, "Loot 0", UDim2.new(0.16, 0, 1, 0), UDim2.new(0.22, 0, 0, 0), Color3.fromRGB(140, 220, 255))
local gemLabel = label(top, "Gems 0", UDim2.new(0.16, 0, 1, 0), UDim2.new(0.38, 0, 0, 0), Color3.fromRGB(120, 255, 210))
local incomeLabel = label(top, "+0/s", UDim2.new(0.14, 0, 1, 0), UDim2.new(0.54, 0, 0, 0), Color3.fromRGB(140, 255, 160))
local clockLabel = label(top, "Day", UDim2.new(0.28, 0, 1, 0), UDim2.new(0.7, 0, 0, 0), Color3.fromRGB(255, 230, 160))
clockLabel.TextXAlignment = Enum.TextXAlignment.Right

local questBanner = label(gui, "", UDim2.new(0.9, 0, 0, 24), UDim2.new(0.05, 0, 0, 86), Color3.fromRGB(255, 244, 180))
questBanner.TextXAlignment = Enum.TextXAlignment.Center

local toast = label(gui, "", UDim2.new(0.6, 0, 0, 28), UDim2.new(0.2, 0, 0, 58), Color3.fromRGB(255, 255, 220))
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.TextStrokeTransparency = 0.4

local bar = Instance.new("ScrollingFrame")
bar.Size = UDim2.new(1, -16, 0, 48)
bar.Position = UDim2.new(0, 8, 1, -56)
bar.BackgroundTransparency = 1
bar.BorderSizePixel = 0
bar.ScrollBarThickness = 4
bar.CanvasSize = UDim2.new(0, 520, 0, 40)
bar.AutomaticCanvasSize = Enum.AutomaticSize.X
bar.Parent = gui
local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.Padding = UDim.new(0, 8)
barLayout.Parent = bar

local function button(text)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 110, 0, 36)
	b.BackgroundColor3 = Color3.fromRGB(40, 90, 50)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.Text = text
	b.Parent = bar
	corner(b, 8)
	return b
end

local rollBtn = button("Roll")
local plantsBtn = button("Plants")
local upgradeBtn = button("Upgrade")
local shopBtn = button("Shop")

local sheet = Instance.new("Frame")
sheet.Size = UDim2.new(0.94, 0, 0.46, 0)
sheet.Position = UDim2.new(0.03, 0, 0.16, 0)
sheet.AnchorPoint = Vector2.new(0, 0)
sheet.BackgroundColor3 = Color3.fromRGB(18, 24, 20)
sheet.BackgroundTransparency = 0.08
sheet.BorderSizePixel = 0
sheet.Visible = true
sheet.Parent = gui
corner(sheet, 12)

local sheetTitle = label(sheet, "Plants", UDim2.new(1, -16, 0, 28), UDim2.new(0, 12, 0, 8))
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -16, 1, -48)
list.Position = UDim2.new(0, 8, 0, 40)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new()
list.Parent = sheet
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = list

local function clearList()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function row(height)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -8, 0, height)
	f.BackgroundColor3 = Color3.fromRGB(32, 42, 34)
	f.BorderSizePixel = 0
	f.Parent = list
	corner(f, 8)
	return f
end

local function smallButton(parent, text, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 72, 0, 26)
	b.Position = UDim2.new(1, x, 0, 8)
	b.BackgroundColor3 = Color3.fromRGB(60, 110, 70)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Text = text
	b.Parent = parent
	corner(b, 6)
	return b
end

local function render()
	clearList()
	if not state then
		return
	end
	coinsLabel.Text = "Coins " .. math.floor(state.coins)
	lootLabel.Text = "Loot " .. math.floor(state.loot)
	gemLabel.Text = "Gems " .. math.floor(state.gems or 0)
	incomeLabel.Text = "+" .. state.income .. "/s"
	local questText = Quests[state.quest or 1] or Quests[#Quests]
	questBanner.Text = "Goal: " .. questText
	if panel == "plants" then
		sheetTitle.Text = "Your plants"
		if #state.plants == 0 then
			local f = row(36)
			label(f, "Roll to get your first plant.", UDim2.new(1, -12, 1, 0), UDim2.new(0, 8, 0, 0))
		end
		for _, plant in state.plants do
			local f = row(42)
			local rare = PlantData.RarityColor[plant.rarity] or Color3.new(1, 1, 1)
			local status = plant.follower and "following" or (plant.tile and ("tile " .. plant.tile) or "stored")
			if plant.stunnedUntil > os.time() then
				status = "stunned " .. (plant.stunnedUntil - os.time()) .. "s"
			elseif (plant.growLeft or 0) > 0 then
				status = "growing " .. plant.growLeft .. "s"
			end
			label(f, plant.name .. "  ·  " .. plant.rarity .. "  ·  " .. status, UDim2.new(0.55, 0, 1, 0), UDim2.new(0, 8, 0, 0), rare)
			if plant.stunnedUntil > os.time() then
				local revive = smallButton(f, "Revive", -80)
				revive.MouseButton1Click:Connect(function()
					Action:FireServer("Revive", plant.uid)
				end)
			else
				local equip = smallButton(f, plant.follower and "Rest" or "Follow", -160)
				equip.MouseButton1Click:Connect(function()
					Action:FireServer(plant.follower and "Unequip" or "Equip", plant.uid)
				end)
				if plant.evolvesInto and (plant.growLeft or 0) <= 0 then
					local evolve = smallButton(f, "Evolve", -248)
					evolve.MouseButton1Click:Connect(function()
						Action:FireServer("Evolve", plant.uid)
					end)
				end
				local place = smallButton(f, "Plant", -80)
				place.MouseButton1Click:Connect(function()
					local tile = 1
					for i = 1, Config.TileCount do
						local taken = false
						for _, other in state.plants do
							if other.tile == i then
								taken = true
							end
						end
						if not taken and not (i == 5 and state.houseLevel < Config.FifthTileHouseLevel) then
							tile = i
							break
						end
					end
					Action:FireServer("Place", tile, plant.uid)
				end)
			end
		end
	elseif panel == "roll" then
		sheetTitle.Text = "Lucky box  ·  " .. Config.RollCost .. " coins"
		for _, id in PlantData.Order do
			local def = PlantData.Plants[id]
			local f = row(32)
			label(f, def.name .. "   " .. def.rarity .. "   " .. (def.chance / 10) .. "%", UDim2.new(1, -12, 1, 0), UDim2.new(0, 8, 0, 0), PlantData.RarityColor[def.rarity])
		end
		local note = row(48)
		label(note, "Odds are shown before you roll. Paid Robux rolls are not in this version.", UDim2.new(1, -12, 1, 0), UDim2.new(0, 8, 0, 0))
	else
		sheetTitle.Text = "House"
		local f = row(80)
		local cost = state.upgradeCost
		local text = cost and ("Upgrade to level " .. (state.houseLevel + 1) .. " for " .. cost .. " coins. Raises income and house health. Level 2 unlocks tile 5.")
			or "House is max level."
		label(f, text, UDim2.new(1, -12, 1, 0), UDim2.new(0, 8, 0, 0))
		label(f, "", UDim2.new(), UDim2.new())
		local buy = smallButton(f, "Buy", -80)
		buy.MouseButton1Click:Connect(function()
			Action:FireServer("Upgrade")
		end)
	elseif panel == "shop" then
		sheetTitle.Text = "Shop"
		for _, offer in Shop.Offers do
			if offer.id == "PaidRoll" and paidRollsHidden then
				continue
			end
			local f = row(48)
			label(f, offer.name .. " — " .. offer.detail, UDim2.new(0.72, 0, 1, 0), UDim2.new(0, 8, 0, 0))
			local buy = smallButton(f, offer.kind == "gems" and "Gems" or "Buy", -80)
			buy.MouseButton1Click:Connect(function()
				if offer.kind == "gems" then
					Action:FireServer("BuyGemPlant")
					return
				end
				local assetId = Shop.Ids[offer.id]
				if not assetId or assetId == 0 then
					toast.Text = "Create this product on the published place, then paste its id into Shop.luau."
					return
				end
				if offer.id == "InstantGrow" or offer.id == "InstantRevive" then
					local target = nil
					for _, plant in state.plants do
						if offer.id == "InstantGrow" and (plant.growLeft or 0) > 0 then
							target = plant.uid
							break
						end
						if offer.id == "InstantRevive" and plant.stunnedUntil > os.time() then
							target = plant.uid
							break
						end
					end
					if not target then
						toast.Text = offer.id == "InstantGrow" and "No plant is growing." or "No plant is stunned."
						return
					end
					Action:FireServer(offer.id == "InstantGrow" and "QueueGrow" or "QueueRevive", target)
				end
				if offer.kind == "pass" then
					MarketplaceService:PromptGamePassPurchase(player, assetId)
				else
					MarketplaceService:PromptProductPurchase(player, assetId)
				end
			end)
		end
	end
	list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
end

local function show(which)
	panel = which
	sheet.Visible = true
	render()
end

rollBtn.MouseButton1Click:Connect(function()
	show("roll")
	local result = Roll:InvokeServer()
	if result and result.ok then
		toast.Text = "You rolled " .. result.name .. " (" .. result.rarity .. ")"
	else
		toast.Text = result and result.message or "Roll failed"
	end
end)
plantsBtn.MouseButton1Click:Connect(function()
	show("plants")
end)
upgradeBtn.MouseButton1Click:Connect(function()
	show("upgrade")
end)
shopBtn.MouseButton1Click:Connect(function()
	show("shop")
end)

StateEvent.OnClientEvent:Connect(function(payload)
	state = payload
	render()
end)

Announce.OnClientEvent:Connect(function(text)
	toast.Text = text
end)

Vfx.OnClientEvent:Connect(function(payload)
	local sound = Instance.new("Sound")
	sound.SoundId = payload.kind == "damage" and "rbxasset://sounds/electronicpingshort.wav" or "rbxasset://sounds/snap.wav"
	sound.Volume = 0.35
	sound.Parent = workspace
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 1)
	if payload.kind == "damage" then
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Position = payload.position + Vector3.new(0, 2, 0)
		anchor.Parent = workspace
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(50, 24)
		gui.AlwaysOnTop = true
		gui.Parent = anchor
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.TextColor3 = payload.color or Color3.new(1, 1, 1)
		text.Text = tostring(math.floor(payload.amount or 0))
		text.Parent = gui
		game:GetService("Debris"):AddItem(anchor, 0.45)
		return
	end
	local bolt = Instance.new("Part")
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = payload.color or Color3.new(1, 1, 1)
	local delta = payload.to - payload.from
	local dist = math.max(delta.Magnitude, 0.2)
	local attack = payload.attack
	if attack == "thorn" or attack == "bite" then
		bolt.Shape = Enum.PartType.Ball
		bolt.Size = Vector3.new(1.4, 1.4, 1.4)
		bolt.CFrame = CFrame.new(payload.to)
	elseif attack == "spore" or attack == "sun" then
		bolt.Shape = Enum.PartType.Ball
		bolt.Size = Vector3.new(4, 4, 4)
		bolt.Transparency = 0.4
		bolt.CFrame = CFrame.new(payload.to)
	else
		bolt.Size = Vector3.new(attack == "lightning" and 0.7 or 0.3, attack == "lightning" and 0.7 or 0.3, dist)
		bolt.CFrame = CFrame.lookAt(payload.from, payload.to) * CFrame.new(0, 0, -dist / 2)
	end
	bolt.Parent = workspace
	game:GetService("Debris"):AddItem(bolt, attack == "lightning" and 0.22 or 0.14)
end)

task.spawn(function()
	while true do
		local phase = ReplicatedStorage:GetAttribute("Phase") or "Day"
		local left = ReplicatedStorage:GetAttribute("TimeLeft") or 0
		local night = ReplicatedStorage:GetAttribute("NightCount") or 0
		local labelText = phase .. "  " .. math.max(0, math.floor(left)) .. "s"
		if phase == "Night" then
			labelText = "Night " .. night .. "  " .. math.max(0, math.floor(left)) .. "s"
			clockLabel.TextColor3 = Color3.fromRGB(200, 140, 255)
		elseif phase == "Warning" then
			clockLabel.TextColor3 = Color3.fromRGB(255, 140, 60)
			labelText = "Return home  " .. math.max(0, math.floor(left)) .. "s"
		else
			clockLabel.TextColor3 = Color3.fromRGB(180, 255, 160)
		end
		clockLabel.Text = labelText
		task.wait(0.25)
	end
end)

task.spawn(function()
	local ok, policy = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and policy and policy.ArePaidRandomItemsRestricted then
		paidRollsHidden = true
	end
end)

print("[PLANT or DIE] Client connected")
render()
