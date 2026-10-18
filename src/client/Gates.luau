--!strict
-- Per-player gate presentation. The server keeps every paid gate's barrier solid; this
-- controller opens barriers locally (CanCollide off for the local character) for biomes
-- the server says you own, updates the sign status line, and runs the unlock prompt + confirm.
-- The server re-checks order and price and enforces locked regions on its own (A7/A8).

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)

local Gates = {}

local function refresh(unlocked: { [string]: boolean })
	local world = workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Gates")
	if not folder then
		return
	end
	for _, b in Biomes.List do
		local gate = folder:FindFirstChild("Gate_" .. b.Id)
		if gate then
			local open = b.Cost == 0 or unlocked[b.Id] == true
			local barrier = gate:FindFirstChild("Barrier") :: BasePart?
			if barrier then
				barrier.CanCollide = not open
				barrier.Transparency = if open then 1 else 0.55
				local prompt = barrier:FindFirstChild("UnlockBiomePrompt") :: ProximityPrompt?
				if prompt then
					prompt.Enabled = not open
				end
			end
			local status = gate:FindFirstChild("Status", true) :: TextLabel?
			if status then
				status.Text = if open then "UNLOCKED" else "LOCKED"
				status.TextColor3 = if open then Ui.Primary else Color3.fromRGB(255, 120, 120)
			end
		end
	end
end

local function promptUnlock(biomeId: string)
	local snap = State.snapshot
	local biome = Biomes.ById[biomeId]
	if not snap or not biome then
		return
	end
	if snap.biomesUnlocked[biomeId] then
		return
	end
	local prev = Biomes.List[biome.Index - 1]
	if prev and prev.Cost > 0 and not snap.biomesUnlocked[prev.Id] then
		Notifications.show(`Unlock {prev.Name} first. Biomes open in order.`, "warn")
		return
	end
	if snap.money < biome.Cost then
		Notifications.show(`Not enough money. {biome.Name} costs {Format.money(biome.Cost)}.`, "error")
		return
	end
	Ui.confirm(
		`Unlock {biome.Name}?`,
		`Permanent access to {biome.Name}: its exclusive seeds, dig spots and guardian.\nPrice: {Format.money(biome.Cost)}`,
		`Buy {Format.money(biome.Cost)}`,
		function()
			State.remote("UnlockBiome"):FireServer(biomeId)
		end
	)
end

function Gates.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "UnlockBiomePrompt" then
			local id = prompt:GetAttribute("BiomeId")
			if type(id) == "string" then
				promptUnlock(id)
			end
		end
	end)
	State.onSnapshot(function(s)
		refresh(s.biomesUnlocked)
	end)
	task.spawn(function()
		local world = workspace:WaitForChild("World")
		world:WaitForChild("Gates")
		if State.snapshot then
			refresh(State.snapshot.biomesUnlocked)
		end
	end)
end

return Gates
