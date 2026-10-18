--!strict
-- Per-player gate presentation. The server keeps every paid gate's barrier solid; this
-- controller opens barriers locally (CanCollide off for the local character) for biomes
-- the server says you own, and updates the sign status line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

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
			end
			local status = gate:FindFirstChild("Status", true) :: TextLabel?
			if status then
				status.Text = if open then "UNLOCKED" else "LOCKED"
				status.TextColor3 = if open then Ui.Primary else Color3.fromRGB(255, 120, 120)
			end
		end
	end
end

function Gates.start()
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
