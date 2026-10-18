--!strict
-- Neon / Mega maker panel (opened from the machine's prompt on your own plot) and the machine
-- billboard timers on every plot. Shows the ingredient rule, progress and timer; every action
-- is a request the server re-validates.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local FusionData = require(ReplicatedStorage.Shared.Fusion)
local Format = require(ReplicatedStorage.Shared.Format)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)
local Purchases = require(script.Parent.Purchases)

local FusionPanel = {}

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Divine" }

local panel: Frame? = nil
local machineId: string? = nil
local ui: { [string]: any } = {}

local function timesText(m: FusionData.Machine): string
	local parts = {}
	for _, r in RARITY_ORDER do
		table.insert(parts, `{r} {Format.duration(m.Seconds[r])}`)
	end
	return table.concat(parts, " · ")
end

local function rulesText(m: FusionData.Machine): string
	local mult = Config.Economy.VariantMultiplier
	return `Put in {FusionData.InputCount} identical fully grown {m.Input} plants from your inventory: same species AND same size. `
		.. `You get 1 {m.Output} plant (x{mult[m.Output]} income vs x{mult[m.Input]}). Species, rarity and size stay.\n{timesText(m)}`
end

type Group = { species: string, size: string, count: number }

local function groups(snap: State.Snapshot, m: FusionData.Machine): { Group }
	local byKey: { [string]: Group } = {}
	for _, item in snap.plants do
		if item.variant == m.Input and Plants.ById[item.species] then
			local key = item.species .. "|" .. item.size
			local g = byKey[key]
			if not g then
				g = { species = item.species, size = item.size, count = 0 }
				byKey[key] = g
			end
			g.count += 1
		end
	end
	local out: { Group } = {}
	for _, g in byKey do
		table.insert(out, g)
	end
	table.sort(out, function(a, b)
		if (a.count >= FusionData.InputCount) ~= (b.count >= FusionData.InputCount) then
			return a.count >= FusionData.InputCount
		end
		return a.species .. a.size < b.species .. b.size
	end)
	return out
end

local function rebuildList()
	local snap = State.snapshot
	local id = machineId
	local list = ui.list :: ScrollingFrame?
	if not snap or not id or not list then
		return
	end
	local m = FusionData.Machines[id]
	local slot = snap.fusion[id]
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local gs = groups(snap, m)
	if #gs == 0 then
		local l = Ui.label("Empty", `No {m.Input} plants in your inventory. Dig up fully grown plants to fuse them.`, false, list)
		l.Size = UDim2.new(1, -8, 0, 44)
		l.TextWrapped = true
		return
	end
	for i, g in gs do
		local def = Plants.ById[g.species]
		local rarity = Rarities.ById[def.Rarity]
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -8, 0, Ui.MinTouch + 4)
		row.Parent = list
		local l = Ui.label("Name", `{def.Name} ({g.size}) {g.count}/{FusionData.InputCount}\n{def.Rarity} · {Format.duration(m.Seconds[def.Rarity])}`, false, row)
		l.Size = UDim2.new(1, -96, 1, 0)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = if rarity then rarity.Color else Ui.Text
		local b = Ui.button("Fuse", "Fuse", row)
		b.Size = UDim2.fromOffset(88, Ui.MinTouch)
		b.Position = UDim2.new(1, -88, 0, 2)
		local ready = g.count >= FusionData.InputCount and slot.unlocked and slot.state == "empty"
		b.BackgroundColor3 = if ready then Ui.Primary else Color3.fromRGB(90, 90, 96)
		b.Activated:Connect(function()
			if not ready then
				Notifications.show(
					if not slot.unlocked then `Build the {m.Name} first.`
						elseif slot.state ~= "empty" then `The {m.Name} is busy.`
						else `Needs {FusionData.InputCount} matching plants.`,
					"warn"
				)
				return
			end
			Ui.confirm(
				`Fuse {def.Name}?`,
				`Uses 4 {m.Input} {def.Name} ({g.size}) from your inventory. In {Format.duration(m.Seconds[def.Rarity])} you get 1 {m.Output} {def.Name} ({g.size}).`,
				"Fuse",
				function()
					State.remote("FusionStart"):FireServer(id, g.species, g.size)
				end
			)
		end)
	end
end

local function refresh()
	local snap = State.snapshot
	local id = machineId
	local p = panel
	if not snap or not id or not p or not p.Visible then
		return
	end
	local m = FusionData.Machines[id]
	local slot = snap.fusion[id]
	local now = State.now()
	local action = ui.action :: TextButton
	local skip = ui.skip :: TextButton
	local fill = ui.fill :: Frame
	local credits = snap.credits[m.SkipProduct] or 0
	skip.Visible = false
	if not slot.unlocked then
		ui.status.Text = `Not built yet. Build cost: {Format.money(m.UnlockCost)}`
		fill.Size = UDim2.fromScale(0, 1)
		action.Text = `Build {Format.money(m.UnlockCost)}`
		action.Visible = true
	elseif slot.state == "empty" then
		ui.status.Text = "Empty. Pick 4 matching plants below."
		fill.Size = UDim2.fromScale(0, 1)
		action.Visible = false
	else
		local def = Plants.ById[slot.species or ""]
		local name = if def then `{def.Name} ({slot.size})` else "?"
		local total = math.max(1, slot.endsAt - slot.startedAt)
		local left = slot.endsAt - now
		fill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
		if left <= 0 then
			ui.status.Text = `Ready: {m.Output} {name}`
			action.Text = "Claim"
			action.Visible = true
		else
			ui.status.Text = `Fusing {name} · {Format.duration(left)} left`
			action.Visible = false
			skip.Visible = true
			skip.Text = if credits > 0 then `Use skip (x{credits})` else "Skip (Robux)"
		end
	end
end

local function onAction()
	local snap = State.snapshot
	local id = machineId
	if not snap or not id then
		return
	end
	local m = FusionData.Machines[id]
	local slot = snap.fusion[id]
	if not slot.unlocked then
		if snap.money < m.UnlockCost then
			Notifications.show(`Not enough money. The {m.Name} costs {Format.money(m.UnlockCost)}.`, "error")
			return
		end
		Ui.confirm(`Build the {m.Name}?`, `Unlocks fusing on this pad forever.\nPrice: {Format.money(m.UnlockCost)}`, `Buy {Format.money(m.UnlockCost)}`, function()
			State.remote("FusionUnlock"):FireServer(id)
		end)
	elseif slot.state ~= "empty" then
		State.remote("FusionClaim"):FireServer(id, slot.runId)
	end
end

local function onSkip()
	local snap = State.snapshot
	local id = machineId
	if not snap or not id then
		return
	end
	local m = FusionData.Machines[id]
	if (snap.credits[m.SkipProduct] or 0) > 0 then
		State.remote("UseCredit"):FireServer(m.SkipProduct)
	else
		Purchases.offer(m.SkipProduct)
	end
end

function FusionPanel.open(id: string)
	local p = panel
	local m = FusionData.Machines[id]
	if not p or not m then
		return
	end
	machineId = id
	ui.title.Text = m.Name
	ui.title.TextColor3 = m.Color
	ui.rules.Text = rulesText(m)
	p.Visible = true
	rebuildList()
	refresh()
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

-- Billboard text on every machine in the world, from the attributes the server sets.
local function updateBillboards()
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	if not plots then
		return
	end
	local now = State.now()
	for _, plot in plots:GetChildren() do
		for _, m in FusionData.Order do
			local model = plot:FindFirstChild(m.Pad)
			local core = model and model:FindFirstChild("Core")
			local bb = core and core:FindFirstChild("Status")
			local label = bb and bb:FindFirstChild("Label") :: TextLabel?
			if model and label then
				if not model:GetAttribute("Unlocked") then
					label.Text = `{m.Name}\nBuild for {Format.money(m.UnlockCost)}`
				elseif model:GetAttribute("State") == "empty" then
					label.Text = `{m.Name}\nEmpty`
				else
					local left = ((model:GetAttribute("EndsAt") :: number?) or 0) - now
					label.Text = if left <= 0 then `{m.Name}\nREADY!` else `{m.Name}\n{Format.duration(left)}`
				end
			end
		end
	end
end

function FusionPanel.start()
	local gui = Ui.screen("Fusion", Players.LocalPlayer:WaitForChild("PlayerGui"), 5)
	local p = Ui.panel("Panel", UDim2.fromOffset(400, 470), gui)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.48)
	p.Visible = false
	panel = p

	local title = Ui.label("Title", "", true, p)
	title.Size = UDim2.new(1, -24, 0, 34)
	title.Position = UDim2.fromOffset(12, 8)
	ui.title = title
	local rules = Ui.label("Rules", "", false, p)
	rules.Size = UDim2.new(1, -24, 0, 96)
	rules.Position = UDim2.fromOffset(12, 46)
	rules.TextWrapped = true
	rules.TextXAlignment = Enum.TextXAlignment.Left
	rules.TextYAlignment = Enum.TextYAlignment.Top
	ui.rules = rules
	local status = Ui.label("Status", "", false, p)
	status.Size = UDim2.new(1, -24, 0, 24)
	status.Position = UDim2.fromOffset(12, 146)
	status.TextXAlignment = Enum.TextXAlignment.Left
	ui.status = status
	local bar = Instance.new("Frame")
	bar.Name = "Progress"
	bar.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, -24, 0, 12)
	bar.Position = UDim2.fromOffset(12, 174)
	bar.Parent = p
	Ui.corner(bar, 6)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Ui.Primary
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	Ui.corner(fill, 6)
	ui.fill = fill

	local action = Ui.button("Action", "Claim", p)
	action.Size = UDim2.new(0.5, -18, 0, Ui.MinTouch)
	action.Position = UDim2.fromOffset(12, 194)
	action.Activated:Connect(onAction)
	ui.action = action
	local skip = Ui.button("Skip", "Skip (Robux)", p)
	skip.BackgroundColor3 = Ui.Warn
	skip.Size = UDim2.new(0.5, -18, 0, Ui.MinTouch)
	skip.Position = UDim2.new(0.5, 6, 0, 194)
	skip.Activated:Connect(onSkip)
	ui.skip = skip

	local sf = Instance.new("ScrollingFrame")
	sf.Name = "List"
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Position = UDim2.fromOffset(10, 246)
	sf.Size = UDim2.new(1, -20, 1, -306)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.CanvasSize = UDim2.new()
	sf.ScrollBarThickness = 6
	sf.Parent = p
	Ui.list(sf, Enum.FillDirection.Vertical, 6)
	ui.list = sf

	local close = Ui.button("Close", "Close", p)
	close.BackgroundColor3 = Color3.fromRGB(90, 90, 96)
	close.Size = UDim2.new(1, -24, 0, Ui.MinTouch)
	close.Position = UDim2.new(0, 12, 1, -(Ui.MinTouch + 10))
	close.Activated:Connect(function()
		p.Visible = false
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name ~= "FusionPrompt" then
			return
		end
		if not ownPlotOf(prompt) then
			Notifications.show("You can only use the machines on your own plot.", "warn")
			return
		end
		FusionPanel.open(prompt:GetAttribute("Machine") :: string)
	end)
	-- Snapshots arrive every income tick; only rebuild the list when its inputs change.
	local lastSig = ""
	State.onSnapshot(function(snap)
		if not p.Visible or not machineId then
			return
		end
		local slot = snap.fusion[machineId]
		local n = 0
		for _ in snap.plants do
			n += 1
		end
		local sig = `{machineId}|{n}|{slot.unlocked}|{slot.state}|{slot.runId}`
		if sig ~= lastSig then
			lastSig = sig
			rebuildList()
		end
		refresh()
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			refresh()
			updateBillboards()
		end
	end)
end

return FusionPanel
