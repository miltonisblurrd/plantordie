--!strict
-- Gives every player one part-built Shovel matching their equipped shovel and one Bat wearing
-- their equipped skin. Skins are looks only: every Bat has the same parts, sizes and grip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Data = require(script.Parent.Data)

local Tools = {}

local GLOW: { [string]: boolean } = { Lava = true, Crystal = true, Galaxy = true, Toxic = true, DivineBloom = true }

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

local function material(hint: string): Enum.Material
	if hint == "Neon" then
		return Enum.Material.SmoothPlastic
	end
	local ok, m = pcall(function()
		return (Enum.Material :: any)[hint]
	end)
	return if ok and m then m else Enum.Material.SmoothPlastic
end

local function piece(tool: Tool, handle: BasePart, name: string, size: Vector3, y: number, color: Color3, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat
	p.CanCollide = false
	p.Massless = true
	p.CFrame = handle.CFrame * CFrame.new(0, y, 0)
	p.Parent = tool
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = p
	w.Parent = p
	return p
end

-- ~4.2 studs: grip 1.4, taper 1.0, barrel 1.6, cap 0.25.
function Tools.buildBat(skinId: string): Tool
	local skin = IndexRewards.SkinById[skinId] or IndexRewards.SkinById[IndexRewards.DefaultSkin]
	local tool = Instance.new("Tool")
	tool.Name = "Bat"
	tool.ToolTip = skin.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -0.4, 0)
	tool:SetAttribute("Skin", skin.Id)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 1.4, 0.35)
	handle.CFrame = CFrame.new()
	handle.Color = skin.Secondary
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local mat = material(skin.Material)
	piece(tool, handle, "Taper", Vector3.new(0.55, 1, 0.55), 1.2, skin.Primary, mat)
	local barrel = piece(tool, handle, "Barrel", Vector3.new(0.8, 1.6, 0.8), 2.5, skin.Primary, mat)
	piece(tool, handle, "Cap", Vector3.new(0.85, 0.25, 0.85), 3.42, skin.Secondary, Enum.Material.SmoothPlastic)
	if GLOW[skin.Id] then
		piece(tool, handle, "Accent", Vector3.new(0.86, 0.18, 0.86), 2.0, skin.Secondary, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = skin.Primary
		light.Range = 6
		light.Brightness = 1.5
		light.Parent = barrel
	end
	return tool
end

-- Replaces every `name` tool in Backpack, StarterGear and character with fresh builds, re-equipping
-- if one was held. StarterGear copies into each new Backpack, so respawns keep one before this reruns.
local function replace(player: Player, name: string, build: () -> Tool)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local equipped = false
	local character = player.Character
	local gear = player:FindFirstChildOfClass("StarterGear")
	local function clear(container: Instance?)
		if not container then
			return
		end
		for _, old in container:GetChildren() do
			if old:IsA("Tool") and old.Name == name then
				equipped = equipped or container == character
				old:Destroy()
			end
		end
	end
	clear(backpack)
	clear(gear)
	clear(character)
	if gear then
		build().Parent = gear
	end
	if not backpack then
		return
	end
	local tool = build()
	tool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if equipped and humanoid then
		humanoid:EquipTool(tool)
	end
end

function Tools.giveShovel(player: Player)
	local session = Data.get(player)
	if not session then
		return
	end
	local tier = session.data.shovels.equipped
	replace(player, "Shovel", function()
		return buildShovel(tier)
	end)
end

function Tools.giveBat(player: Player)
	local session = Data.get(player)
	if not session then
		return
	end
	local skin = session.data.batSkins.equipped
	replace(player, "Bat", function()
		return Tools.buildBat(skin)
	end)
end

local function giveAll(player: Player)
	Tools.giveShovel(player)
	Tools.giveBat(player)
end

function Tools.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(giveAll, player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Data.onLoaded(giveAll)
end

return Tools
