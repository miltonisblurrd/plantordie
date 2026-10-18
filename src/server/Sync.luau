--!strict
-- Pushes the HUD-facing snapshot of server state to each client and tracks which area each
-- player stands in. The client renders this; it never computes money or income itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Houses = require(ReplicatedStorage.Shared.Houses)
local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Events = require(ReplicatedStorage.Shared.Events)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)
local Biomes = require(script.Parent.Biomes)

local Sync = {}

type Runtime = { area: string, houseHp: number }
local runtime: { [Player]: Runtime } = {}

-- Income/sec is owned by Garden (P2). Until then it is always 0.
local incomeProvider: (Player) -> number = function(_player: Player)
	return 0
end

function Sync.setIncomeProvider(fn: (Player) -> number)
	incomeProvider = fn
end

local function areaFor(player: Player): string
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return "Hub"
	end
	local pos = root.Position
	local idx = Plots.plotAt(pos)
	if idx then
		if Plots.isOwner(player, idx) then
			return "Your Plot"
		end
		local owner = Plots.ownerOf(idx)
		return if owner then `{owner.Name}'s Plot` else "Empty Plot"
	end
	local flat = Vector3.new(pos.X, 0, pos.Z)
	if flat.Magnitude <= Config.World.GateRingRadius + 20 then
		return "Hub"
	end
	for _, b in BiomeData.List do
		local anchor = Biomes.anchor(b.Id)
		if anchor and (anchor.Position - pos).Magnitude < 300 then
			return b.Name
		end
	end
	return "Hub"
end

function Sync.push(player: Player)
	local session = Data.get(player)
	local rt = runtime[player]
	if not session or not rt then
		return
	end
	local d = session.data
	local house = Houses.List[d.houseTier] or Houses.List[1]
	local event = Events.active(os.time())
	Net.fire("StateSync", player, {
		money = d.money,
		incomePerSec = incomeProvider(player),
		houseTier = d.houseTier,
		houseName = house.Name,
		houseHp = rt.houseHp,
		houseMaxHp = house.MaxHp,
		lanesUnlocked = d.lanesUnlocked,
		biomesUnlocked = d.biomesUnlocked,
		plotIndex = Plots.plotOf(player) or 0,
		area = rt.area,
		event = if event then { name = event.Name, endsAt = event.EndsAt } else nil,
		persistent = Data.mode() == "DataStore",
	})
end

function Sync.start()
	Data.onLoaded(function(player, session)
		local house = Houses.List[session.data.houseTier] or Houses.List[1]
		runtime[player] = { area = "Hub", houseHp = house.MaxHp }
		-- Plot assignment runs in its own onLoaded callback; let it settle first.
		task.defer(Sync.push, player)
	end)
	Data.onChanged(function(player)
		Sync.push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		runtime[player] = nil
	end)
	Net.on("RequestState", {}, function(player)
		Sync.push(player)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Sync.AreaCheckSeconds)
			for player, rt in runtime do
				local area = areaFor(player)
				if area ~= rt.area then
					rt.area = area
					Sync.push(player)
				end
			end
		end
	end)
end

return Sync
