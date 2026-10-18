--!strict
-- Night defense UI: the incoming-attack and wave banner, zombie health bars, click or tap a
-- zombie to hit it, combat VFX from CombatFx, repair and trap buttons, and night lighting.
-- Everything shown comes from the snapshot, the DayNight event or model attributes.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local Defense = {}

local player = Players.LocalPlayer
local zombieFolders: { Instance } = {}
local BAR_MAX_DISTANCE = 140
local FX_MAX_DISTANCE = 220

local function healthBar(m: Model)
	local root = m.PrimaryPart
	if not root then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Size = UDim2.fromScale(4, 0.45)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.2 * (root.Size.Y / 2.6), 0)
	gui.MaxDistance = BAR_MAX_DISTANCE
	gui.AlwaysOnTop = true
	gui.Adornee = root
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(40, 20, 24)
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Ui.Danger
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	local function update()
		local hp = m:GetAttribute("Hp")
		local max = m:GetAttribute("MaxHp")
		if type(hp) == "number" and type(max) == "number" and max > 0 then
			fill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
		end
	end
	m:GetAttributeChangedSignal("Hp"):Connect(update)
	update()
	gui.Parent = root
end

local function watchFolder(folder: Instance)
	table.insert(zombieFolders, folder)
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.defer(healthBar, child)
		end
	end)
	folder.AncestryChanged:Connect(function(_, parent)
		if not parent then
			local i = table.find(zombieFolders, folder)
			if i then
				table.remove(zombieFolders, i)
			end
		end
	end)
end

local function watchPlots()
	local plots = workspace:WaitForChild("World"):WaitForChild("Plots")
	local function onPlot(plot: Instance)
		plot.ChildAdded:Connect(function(child)
			if child.Name == "Zombies" then
				watchFolder(child)
			end
		end)
		local existing = plot:FindFirstChild("Zombies")
		if existing then
			watchFolder(existing)
		end
	end
	for _, plot in plots:GetChildren() do
		onPlot(plot)
	end
	plots.ChildAdded:Connect(onPlot)
end

local function clickZombie(screen: Vector2)
	if #zombieFolders == 0 then
		return
	end
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = zombieFolders
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	local m = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	local id = m and m:GetAttribute("ZombieId")
	if m and type(id) == "number" and m:GetAttribute("Owner") == player.UserId then
		State.remote("HitZombie"):FireServer(id)
		local root = m.PrimaryPart
		if root then
			local flash = Instance.new("Highlight")
			flash.FillColor = Color3.new(1, 1, 1)
			flash.FillTransparency = 0.4
			flash.OutlineTransparency = 1
			flash.Parent = m
			Debris:AddItem(flash, 0.12)
		end
	end
end

local function fxPart(color: Color3, size: Vector3, cf: CFrame, shape: Enum.PartType): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Shape = shape
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = workspace.CurrentCamera
	return p
end

type Fx = { k: string, a: Vector3, b: Vector3?, r: number?, c: Color3? }

local function playFx(list: { Fx })
	local camPos = workspace.CurrentCamera.CFrame.Position
	local shown = 0
	for _, f in list do
		if shown >= 30 then
			break
		end
		if (f.a - camPos).Magnitude <= FX_MAX_DISTANCE then
			shown += 1
			local color = f.c or Color3.new(1, 1, 1)
			if f.k == "bolt" and f.b then
				local p = fxPart(color, Vector3.new(0.7, 0.7, 0.7), CFrame.new(f.a), Enum.PartType.Ball)
				local t = math.clamp((f.b - f.a).Magnitude / 120, 0.06, 0.3)
				TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = CFrame.new(f.b) }):Play()
				Debris:AddItem(p, t + 0.02)
			elseif f.k == "ring" then
				local r = f.r or 6
				local p = fxPart(color, Vector3.new(0.3, 2, 2), CFrame.new(f.a) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
				p.Transparency = 0.3
				TweenService:Create(p, TweenInfo.new(0.35), { Size = Vector3.new(0.3, r * 2, r * 2), Transparency = 1 }):Play()
				Debris:AddItem(p, 0.4)
			elseif f.k == "pop" then
				local p = fxPart(Color3.fromRGB(150, 200, 110), Vector3.new(1, 1, 1), CFrame.new(f.a), Enum.PartType.Ball)
				TweenService:Create(p, TweenInfo.new(0.3), { Size = Vector3.new(4, 4, 4), Transparency = 1 }):Play()
				Debris:AddItem(p, 0.35)
			end
		end
	end
end

local function nightLighting()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "NightTint"
	cc.Parent = Lighting
	State.onDayNight(function(info)
		local night = info.phase == "Night"
		TweenService:Create(cc, TweenInfo.new(4), {
			TintColor = if night then Color3.fromRGB(190, 200, 255) else Color3.new(1, 1, 1),
			Brightness = if night then -0.04 else 0,
			Saturation = if night then -0.15 else 0,
		}):Play()
	end)
end

function Defense.start()
	local gui = Ui.screen("Defense", player:WaitForChild("PlayerGui"), 6)

	local banner = Ui.panel("Banner", UDim2.fromOffset(440, 56), gui)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 12)
	banner.Visible = false
	local bannerText = Ui.label("Text", "", true, banner)
	bannerText.Size = UDim2.new(1, -16, 1, -8)
	bannerText.Position = UDim2.fromOffset(8, 4)

	-- Night action buttons sit right above the action bar.
	local actions = Instance.new("Frame")
	actions.Name = "DefenseActions"
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(0.5, 1)
	actions.Position = UDim2.new(0.5, 0, 1, -72)
	actions.Size = UDim2.fromOffset(390, Ui.MinTouch)
	actions.Visible = false
	actions.Parent = gui
	Ui.list(actions, Enum.FillDirection.Horizontal, 10).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local repair = Ui.button("Repair", "Repair", actions)
	repair.Size = UDim2.fromOffset(120, Ui.MinTouch)
	local spikes = Ui.button("Spikes", "Spikes", actions)
	spikes.Size = UDim2.fromOffset(120, Ui.MinTouch)
	spikes.BackgroundColor3 = Color3.fromRGB(110, 110, 124)
	local freeze = Ui.button("Freeze", "Freeze", actions)
	freeze.Size = UDim2.fromOffset(120, Ui.MinTouch)
	freeze.BackgroundColor3 = Color3.fromRGB(70, 150, 210)

	repair.Activated:Connect(function()
		local s = State.snapshot
		local d = s and s.defense
		if not d then
			return
		end
		Ui.confirm("Repair", `Restore your house to full HP and revive {d.wilted} wilted plant(s) for {Format.money(d.repairCost)}.`,
			"Repair", function()
				State.remote("Repair"):FireServer()
			end)
	end)
	local function trapButton(button: TextButton, kind: string, body: string)
		button.Activated:Connect(function()
			local s = State.snapshot
			local d = s and s.defense
			if not d then
				return
			end
			Ui.confirm(kind, `{body} Costs {Format.money(d.traps[kind].cost)}.`, "Place", function()
				State.remote("UseTrap"):FireServer(kind)
			end)
		end)
	end
	local T = Config.Defense.Traps
	trapButton(spikes, "Spikes", `Lay a spike strip in front of the closest zombie for {T.Spikes.Seconds}s.`)
	trapButton(freeze, "Freeze", `Drop a freeze mine that stops nearby zombies for {T.Freeze.Seconds}s.`)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local t = workspace:GetServerTimeNow()
		local dn = State.dayNight
		local s = State.snapshot
		local d = s and s.defense
		local text, color = nil :: string?, Ui.Text
		if dn and dn.phase == "Day" and dn.endsAt - t <= Config.Defense.WarningSeconds then
			text = `ZOMBIES ATTACK IN {Format.clock(dn.endsAt - t)}. Get home!`
			color = Ui.Warn
		elseif d and d.lost then
			text = "Your house fell. Wave lost. Repair and hold on until dawn!"
			color = Ui.Danger
		elseif d and d.active then
			text = `NIGHT {d.night}: {d.remaining} zombie{if d.remaining == 1 then "" else "s"} left{if d.boss then " + ROT KING" else ""}`
			color = Color3.fromRGB(190, 180, 255)
		end
		banner.Visible = text ~= nil
		bannerText.Text = text or ""
		bannerText.TextColor3 = color
		local night = dn ~= nil and dn.phase == "Night"
		actions.Visible = d ~= nil and (night or d.repairNeeded)
		if d then
			local rLeft = d.repairReadyAt - t
			repair.Text = if rLeft > 0 then `Repair {math.ceil(rLeft)}s` else `Repair {Format.money(d.repairCost)}`
			repair.Visible = d.repairNeeded
			local trapButtons: { [string]: TextButton } = { Spikes = spikes, Freeze = freeze }
			for kind, button in trapButtons do
				local left = d.traps[kind].readyAt - t
				button.Visible = night and d.active
				button.Text = if left > 0 then `{kind} {math.ceil(left)}s` else kind
				button.AutoButtonColor = left <= 0
			end
		end
	end)

	State.remote("CombatFx").OnClientEvent:Connect(playFx)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			clickZombie(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	nightLighting()
	task.spawn(watchPlots)
end

return Defense
