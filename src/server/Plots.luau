--!strict
-- Owns plot instances and assignment. One owner per plot, one plot per player, for the session.
-- Every later system checks ownership through ownerOf / isOwner / plotOf.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Layout = require(script.Parent.World.Layout)
local PlotBuilder = require(script.Parent.World.Builders.Plot)

local Plots = {}

local refsByIndex: { [number]: PlotBuilder.PlotRefs } = {}
local ownerByIndex: { [number]: Player } = {}
local indexByPlayer: { [Player]: number } = {}
local charConns: { [Player]: RBXScriptConnection } = {}

local function resolveIndex(plot: number | Instance): number?
	if type(plot) == "number" then
		return plot
	end
	local inst: Instance? = plot
	while inst do
		local idx = inst:GetAttribute("PlotIndex")
		if type(idx) == "number" then
			return idx
		end
		inst = inst.Parent
	end
	return nil
end

function Plots.ownerOf(tileOrPlot: number | Instance): Player?
	local idx = resolveIndex(tileOrPlot)
	return if idx then ownerByIndex[idx] else nil
end

function Plots.isOwner(player: Player, plot: number | Instance): boolean
	local idx = resolveIndex(plot)
	return idx ~= nil and ownerByIndex[idx] == player and indexByPlayer[player] == idx
end

function Plots.plotOf(player: Player): number?
	return indexByPlayer[player]
end

function Plots.refs(index: number): PlotBuilder.PlotRefs?
	return refsByIndex[index]
end

-- Returns the plot index whose footprint contains `pos`, if any.
function Plots.plotAt(pos: Vector3): number?
	local P = Config.Plot
	for idx, refs in refsByIndex do
		local o = refs.cframe:PointToObjectSpace(pos)
		if math.abs(o.X) <= P.Width / 2 and math.abs(o.Z) <= P.Depth / 2 then
			return idx
		end
	end
	return nil
end

function Plots.spawnCFrame(player: Player): CFrame?
	local idx = indexByPlayer[player]
	local refs = idx and refsByIndex[idx]
	return if refs then refs.spawn else nil
end

-- Re-applies saved visuals (lanes, house) for the player's plot. Call after purchases.
function Plots.refresh(player: Player)
	local idx = indexByPlayer[player]
	local session = Data.get(player)
	if not idx or not session then
		return
	end
	local refs = refsByIndex[idx]
	PlotBuilder.setLanes(refs, session.data.lanesUnlocked)
	PlotBuilder.setHouseTier(refs, session.data.houseTier)
end

local function teleportHome(player: Player, character: Model)
	local cf = Plots.spawnCFrame(player)
	if not cf then
		return
	end
	if not character:FindFirstChild("HumanoidRootPart") then
		character:WaitForChild("HumanoidRootPart", 5)
	end
	if character.Parent then
		character:PivotTo(cf)
	end
end

local function assign(player: Player, session: Data.Session)
	if indexByPlayer[player] or not player.Parent then
		return
	end
	local free: number? = nil
	for i = 1, Config.World.PlotCount do
		if not ownerByIndex[i] then
			free = i
			break
		end
	end
	if not free then
		Net.notify(player, "All plots are taken right now. You can still explore the hub!", "warn")
		return
	end
	-- No yields between the free check and these writes, so two joins can't claim the same plot.
	ownerByIndex[free] = player
	indexByPlayer[player] = free
	session.data.plotIndex = free

	local refs = refsByIndex[free]
	refs.model:SetAttribute("OwnerUserId", player.UserId)
	refs.ownerLabel.Text = player.Name
	Plots.refresh(player)

	charConns[player] = player.CharacterAdded:Connect(function(character)
		teleportHome(player, character)
	end)
	if player.Character then
		task.spawn(teleportHome, player, player.Character)
	end
end

local function release(player: Player)
	local idx = indexByPlayer[player]
	if charConns[player] then
		charConns[player]:Disconnect()
		charConns[player] = nil
	end
	if not idx then
		return
	end
	indexByPlayer[player] = nil
	if ownerByIndex[idx] == player then
		ownerByIndex[idx] = nil
	end
	local refs = refsByIndex[idx]
	refs.model:SetAttribute("OwnerUserId", nil)
	refs.ownerLabel.Text = "Empty Plot"
	PlotBuilder.setLanes(refs, Config.Start.LanesUnlocked)
	PlotBuilder.setHouseTier(refs, 1)
end

function Plots.start(worldFolder: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = worldFolder
	for i = 1, Config.World.PlotCount do
		local refs = PlotBuilder.build(i, Layout.plotCFrame(i), folder)
		PlotBuilder.setLanes(refs, Config.Start.LanesUnlocked)
		refsByIndex[i] = refs
	end

	Data.onLoaded(assign)
	Data.onReleasing(function(player)
		release(player)
	end)
	Players.PlayerRemoving:Connect(release)
end

return Plots
