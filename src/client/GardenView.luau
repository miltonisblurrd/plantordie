--!strict
-- Updates plant billboards (growth timer, then income) from server-set attributes, and runs
-- the Mega rainbow hue cycle (off under reduced effects). New plant models pop in, which covers
-- planting and every growth stage since the server rebuilds the model per stage. Display only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Effects = require(script.Parent.Effects)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.State)

local GardenView = {}

local GROWN = Color3.fromHex("#3FBF4A")

local function updateLabels()
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	if not plots then
		return
	end
	local now = os.time()
	for _, plot in plots:GetChildren() do
		local folder = plot:FindFirstChild("Plants")
		if folder then
			for _, m in folder:GetChildren() do
				local info = m:FindFirstChild("Info")
				local label = info and info:FindFirstChild("Label") :: TextLabel?
				if label then
					local stage = (m:GetAttribute("Stage") :: number?) or 1
					local rate = `+{Format.money((m:GetAttribute("Income") :: number?) or 0)}/s`
					if stage >= 4 then
						label.Text = rate
						label.TextColor3 = GROWN
					else
						local planted = (m:GetAttribute("PlantedAt") :: number?) or now
						local total = (m:GetAttribute("GrowSeconds") :: number?) or 1
						label.Text = `{Economy.STAGES[stage]} {Format.clock(planted + total - now)}\n{rate}`
						label.TextColor3 = Color3.new(1, 1, 1)
					end
				end
			end
		end
	end
end

local function watchPlantFolder(plot: Instance, folder: Instance)
	folder.ChildRemoved:Connect(function(m)
		if not m:IsA("Model") then
			return
		end
		local root = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
		if not root then
			return
		end
		local at = root.Position
		Sfx.play("Dig")
		local puff = Instance.new("Part")
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.Transparency = 1
		puff.Size = Vector3.one
		puff.Position = at
		puff.Parent = workspace
		local dirt = Instance.new("ParticleEmitter")
		dirt.Color = ColorSequence.new(Color3.fromRGB(120, 84, 52))
		dirt.Size = NumberSequence.new(0.6, 0)
		dirt.Speed = NumberRange.new(6, 12)
		dirt.Lifetime = NumberRange.new(0.3, 0.6)
		dirt.SpreadAngle = Vector2.new(40, 40)
		dirt.Rate = 0
		dirt.Parent = puff
		dirt:Emit(18)
		game:GetService("Debris"):AddItem(puff, 1)
	end)
	folder.ChildAdded:Connect(function(m)
		if not m:IsA("Model") then
			return
		end
		task.defer(function()
			if not m.Parent then
				return
			end
			Effects.pop(m)
			local snap = State.snapshot
			if snap and plot.Name == `Plot_{snap.plotIndex}` and m:GetAttribute("Stage") == 1 then
				Sfx.play("Plant")
			end
		end)
	end)
end

local function watchPlots()
	local world = workspace:WaitForChild("World")
	local plots = world:WaitForChild("Plots")
	local function onPlot(plot: Instance)
		local folder = plot:FindFirstChild("Plants")
		if folder then
			watchPlantFolder(plot, folder)
			return
		end
		plot.ChildAdded:Connect(function(c)
			if c.Name == "Plants" then
				watchPlantFolder(plot, c)
			end
		end)
	end
	for _, plot in plots:GetChildren() do
		onPlot(plot)
	end
	plots.ChildAdded:Connect(onPlot)
end

function GardenView.start()
	task.spawn(watchPlots)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			updateLabels()
		end
		if Effects.reduced() then
			return
		end
		local hue = (os.clock() * 0.15) % 1
		for _, m in CollectionService:GetTagged("MegaPlant") do
			local h = m:FindFirstChild("Head")
			if h and h:IsA("BasePart") then
				h.Color = Color3.fromHSV(hue, 0.8, 1)
			end
		end
	end)
end

return GardenView
