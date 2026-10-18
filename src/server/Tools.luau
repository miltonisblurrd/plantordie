--!strict
-- Gives every player a part-built Shovel tool matching their saved shovel tier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Data = require(script.Parent.Data)

local Tools = {}

local function buildShovel(tier: number): Tool
	local def = Upgrades.Shovels[tier] or Upgrades.Shovels[1]
	local tool = Instance.new("Tool")
	tool.Name = "Shovel"
	tool.ToolTip = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -1.2, 0)
	tool:SetAttribute("Tier", def.Tier)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 4.4, 0.4)
	handle.Color = Color3.fromRGB(139, 98, 60)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(1.6, 1.8, 0.25)
	blade.Color = def.Color
	blade.Material = if def.Tier >= 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	blade.CanCollide = false
	blade.Massless = true
	blade.CFrame = handle.CFrame * CFrame.new(0, -3, 0)
	blade.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = blade
	weld.Parent = blade
	return tool
end

function Tools.giveShovel(player: Player)
	local session = Data.get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not session or not backpack then
		return
	end
	local equipped = false
	local character = player.Character
	local oldInBag = backpack:FindFirstChild("Shovel")
	if oldInBag then
		oldInBag:Destroy()
	end
	local held = character and character:FindFirstChild("Shovel")
	if held then
		equipped = true
		held:Destroy()
	end
	local tool = buildShovel(session.data.shovelTier)
	tool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if equipped and humanoid then
		humanoid:EquipTool(tool)
	end
end

function Tools.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(Tools.giveShovel, player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Data.onLoaded(function(player)
		Tools.giveShovel(player)
	end)
end

return Tools
