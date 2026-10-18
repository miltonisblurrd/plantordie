--!strict
-- Upgrades panel (house tier + next lane) and the lane-sign prompts. Every purchase opens a
-- confirm stating the exact benefit and price; the server re-validates.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Houses = require(ReplicatedStorage.Shared.Houses)
local Lanes = require(ReplicatedStorage.Shared.Lanes)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)

local Shops = {}

local function promptLane()
	local snap = State.snapshot
	if not snap then
		return
	end
	local lane = snap.lanesUnlocked + 1
	local price = Lanes.price(lane)
	if lane > Config.Plot.Lanes or not price then
		Notifications.show("All lanes are unlocked.", "info")
		return
	end
	if snap.money < price then
		Notifications.show(`Not enough money. Lane {lane} costs {Format.money(price)}.`, "error")
		return
	end
	Ui.confirm(
		`Unlock lane {lane}?`,
		`Adds {Config.Plot.Columns} soil tiles in lane {lane} for planting and defense.\nPrice: {Format.money(price)}`,
		`Buy {Format.money(price)}`,
		function()
			State.remote("BuyLane"):FireServer()
		end
	)
end

local function promptHouse()
	local snap = State.snapshot
	if not snap then
		return
	end
	local nextDef = Houses.List[snap.houseTier + 1]
	if not nextDef then
		Notifications.show("Your house is already max tier.", "info")
		return
	end
	local req = BiomeData.List[nextDef.RequiredBiome]
	if req and req.Cost > 0 and not snap.biomesUnlocked[req.Id] then
		Notifications.show(`{nextDef.Name} requires {req.Name} to be unlocked.`, "error")
		return
	end
	if snap.money < nextDef.Cost then
		Notifications.show(`Not enough money. {nextDef.Name} costs {Format.money(nextDef.Cost)}.`, "error")
		return
	end
	Ui.confirm(
		`Upgrade to {nextDef.Name}?`,
		`Max HP {snap.houseMaxHp} → {nextDef.MaxHp}, plant slots {snap.houseSlots} → {nextDef.Slots}.\nPrice: {Format.money(nextDef.Cost)}`,
		`Buy {Format.money(nextDef.Cost)}`,
		function()
			State.remote("BuyHouse"):FireServer()
		end
	)
end

local function ownPlotOf(inst: Instance): boolean
	local snap = State.snapshot
	local node: Instance? = inst
	while node do
		local idx = node:GetAttribute("PlotIndex")
		if idx ~= nil then
			return snap ~= nil and idx == snap.plotIndex
		end
		node = node.Parent
	end
	return false
end

function Shops.start(bar: Frame)
	local gui = Ui.screen("Upgrades", Players.LocalPlayer:WaitForChild("PlayerGui"), 4)
	local p = Ui.panel("Panel", UDim2.fromOffset(340, 250), gui)
	p.AnchorPoint = Vector2.new(0.5, 1)
	p.Position = UDim2.new(0.5, 0, 1, -76)
	p.Visible = false
	local title = Ui.label("Title", "Upgrades", true, p)
	title.Size = UDim2.new(1, -24, 0, 34)
	title.Position = UDim2.fromOffset(12, 8)

	local houseInfo = Ui.label("HouseInfo", "", false, p)
	houseInfo.Size = UDim2.new(1, -24, 0, 50)
	houseInfo.Position = UDim2.fromOffset(12, 46)
	houseInfo.TextWrapped = true
	houseInfo.TextXAlignment = Enum.TextXAlignment.Left
	local houseBtn = Ui.button("BuyHouse", "Upgrade House", p)
	houseBtn.Size = UDim2.new(1, -24, 0, Ui.MinTouch)
	houseBtn.Position = UDim2.fromOffset(12, 98)
	houseBtn.Activated:Connect(promptHouse)

	local laneInfo = Ui.label("LaneInfo", "", false, p)
	laneInfo.Size = UDim2.new(1, -24, 0, 30)
	laneInfo.Position = UDim2.fromOffset(12, 150)
	laneInfo.TextXAlignment = Enum.TextXAlignment.Left
	local laneBtn = Ui.button("BuyLane", "Unlock Lane", p)
	laneBtn.Size = UDim2.new(1, -24, 0, Ui.MinTouch)
	laneBtn.Position = UDim2.fromOffset(12, 186)
	laneBtn.Activated:Connect(promptLane)

	local open = Ui.button("Upgrades", "Upgrades", bar)
	open.LayoutOrder = 2
	open.Size = UDim2.fromOffset(130, Ui.MinTouch + 4)
	open.Activated:Connect(function()
		p.Visible = not p.Visible
	end)

	State.onSnapshot(function(s)
		local nextDef = Houses.List[s.houseTier + 1]
		if nextDef then
			local req = BiomeData.List[nextDef.RequiredBiome]
			houseInfo.Text = `{s.houseName} → {nextDef.Name}: {Format.money(nextDef.Cost)}`
				.. (if req and req.Cost > 0 then ` (needs {req.Name})` else "")
			houseBtn.Visible = true
		else
			houseInfo.Text = `{s.houseName} (max tier)`
			houseBtn.Visible = false
		end
		local lane = s.lanesUnlocked + 1
		local price = Lanes.price(lane)
		if price and lane <= Config.Plot.Lanes then
			laneInfo.Text = `Next: lane {lane} for {Format.money(price)}`
			laneBtn.Visible = true
		else
			laneInfo.Text = "All lanes unlocked"
			laneBtn.Visible = false
		end
	end)

	-- Lane-sign prompts: only usable on your own plot.
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "BuyLanePrompt" and not ownPlotOf(prompt) then
			prompt.Enabled = false
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name ~= "BuyLanePrompt" or not ownPlotOf(prompt) then
			return
		end
		local snap = State.snapshot
		local lane = prompt:GetAttribute("Lane")
		if snap and lane ~= snap.lanesUnlocked + 1 then
			Notifications.show(`Unlock lanes in order. Next is lane {snap.lanesUnlocked + 1}.`, "warn")
			return
		end
		promptLane()
	end)
end

return Shops
