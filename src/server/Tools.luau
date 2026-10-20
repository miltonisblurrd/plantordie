--!strict
-- Gives every player a part-built Shovel tool matching their equipped shovel.

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
	blade.Material = def.Material
	blade.CanCollide = false
	blade.Massless = true
	blade.CFrame = handle.CFrame * CFrame.new(0, -3, 0)
	blade.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = blade
	weld.Parent = blade

	local collar = Instance.new("Part")
	collar.Name = "Collar"
	collar.Size = Vector3.new(0.6, 0.5, 0.6)
	collar.Color = def.Accent
	collar.Material = Enum.Material.SmoothPlastic
	collar.CanCollide = false
	collar.Massless = true
	collar.CFrame = handle.CFrame * CFrame.new(0, -2.05, 0)
	collar.Parent = tool
	local collarWeld = Instance.new("WeldConstraint")
	collarWeld.Part0 = handle
	collarWeld.Part1 = collar
	collarWeld.Parent = collar

	if def.Effect == "Fire" then
		local fire = Instance.new("Fire")
		fire.Color = def.Color
		fire.SecondaryColor = def.Accent
		fire.Size = 2
		fire.Heat = 3
		fire.Parent = blade
	elseif def.Effect then
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = if def.Effect == "Smoke" then "rbxasset://textures/particles/smoke_main.dds" else "rbxasset://textures/particles/sparkles_main.dds"
		fx.Color = ColorSequence.new(def.Color, def.Accent)
		fx.LightEmission = if def.Effect == "Smoke" then 0.2 else 0.8
		fx.Size = NumberSequence.new(if def.Effect == "Stars" then 0.35 else 0.25, 0)
		fx.Lifetime = NumberRange.new(0.5, 0.9)
		fx.Speed = NumberRange.new(0.5, 1.5)
		fx.SpreadAngle = Vector2.new(180, 180)
		fx.Rate = if def.Effect == "Stars" then 10 else 6
		fx.Parent = blade
	end
	return tool
end

function Tools.giveShovel(player: Player)
	local session = Data.get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not session then
		return
	end
	local equipped = false
	local character = player.Character
	local gear = player:FindFirstChildOfClass("StarterGear")
	local function clear(container: Instance?)
		if not container then
			return
		end
		for _, old in container:GetChildren() do
			if old:IsA("Tool") and old.Name == "Shovel" then
				equipped = equipped or container == character
				old:Destroy()
			end
		end
	end
	clear(backpack)
	clear(gear)
	clear(character)
	local tier = session.data.shovels.equipped
	-- StarterGear copies into each new Backpack, so respawns keep a shovel even before this reruns.
	if gear then
		buildShovel(tier).Parent = gear
	end
	if not backpack then
		return
	end
	local tool = buildShovel(tier)
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
