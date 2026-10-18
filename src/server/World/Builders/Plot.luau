--!strict
-- Builds one personal plot. Local frame: origin at ground centre, -Z faces the hub,
-- lanes run along X with the house on the left (-X) and zombies entering from the right (+X).
-- Lane 1 is the far row from the hub side, lane 7 the nearest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lanes = require(ReplicatedStorage.Shared.Lanes)
local Format = require(ReplicatedStorage.Shared.Format)
local Parts = require(script.Parent.Parent.Parts)
local House = require(script.Parent.House)

local P = Config.Plot
local T = P.TileSize

local SOIL = Color3.fromRGB(122, 82, 52)
local SOIL_LOCKED = Color3.fromRGB(70, 66, 64)
local GRASS = Color3.fromRGB(92, 200, 80)
local PATH = Color3.fromRGB(176, 150, 110)
local PRIMARY = Color3.fromHex("#3FBF4A")

export type PlotRefs = {
	index: number,
	cframe: CFrame,
	model: Model,
	tiles: { [string]: BasePart },
	laneLocks: { [number]: Model },
	houseBase: CFrame,
	house: Model,
	ownerLabel: TextLabel,
	spawn: CFrame,
}

local PlotBuilder = {}

function PlotBuilder.tileKey(lane: number, col: number): string
	return `{lane}_{col}`
end

function PlotBuilder.laneZ(lane: number): number
	return ((P.Lanes + 1) / 2 - lane) * T
end

function PlotBuilder.colX(col: number): number
	return P.GardenOriginX + (col - 0.5) * T
end

function PlotBuilder.gardenCenter(cf: CFrame): CFrame
	return cf * CFrame.new(P.GardenOriginX + P.Columns * T / 2, 0, 0)
end

local function buildLaneLock(refs: PlotRefs, lane: number)
	local cf = refs.cframe
	local m = Parts.model(`LaneLock_{lane}`, refs.model)
	local z = PlotBuilder.laneZ(lane)
	local gardenW = P.Columns * T
	local midX = P.GardenOriginX + gardenW / 2
	Parts.make({
		Name = "Rope", Parent = m, Color = Color3.fromRGB(255, 176, 32), CanCollide = false,
		Size = Vector3.new(gardenW, 0.3, 0.3), CFrame = cf * CFrame.new(midX, 1.6, z),
	})
	for _, x in { P.GardenOriginX, P.GardenOriginX + gardenW } do
		Parts.make({
			Name = "Post", Parent = m, Color = Color3.fromRGB(110, 74, 44),
			Size = Vector3.new(0.8, 2.4, 0.8), CFrame = cf * CFrame.new(x, 1.2, z),
		})
	end
	local signX = P.GardenOriginX + gardenW + 4
	Parts.make({
		Name = "SignPost", Parent = m, Color = Color3.fromRGB(110, 74, 44),
		Size = Vector3.new(0.6, 4, 0.6), CFrame = cf * CFrame.new(signX, 2, z),
	})
	local board = Parts.make({
		Name = "SignBoard", Parent = m, Color = Color3.fromHex("#1E2A22"),
		Size = Vector3.new(7, 3.4, 0.4), CFrame = cf * CFrame.new(signX, 4.6, z),
	})
	local price = Lanes.price(lane) or 0
	local text = `LANE {lane} LOCKED\n{Format.money(price)}`
	-- Front faces the hub side (where the plot camera sits); back for players inside the garden.
	Parts.surfaceText(board, Enum.NormalId.Front, text, Color3.fromRGB(255, 220, 120))
	Parts.surfaceText(board, Enum.NormalId.Back, text, Color3.fromRGB(255, 220, 120))
	refs.laneLocks[lane] = m
end

local function buildPad(refs: PlotRefs, name: string, label: string, x: number, color: Color3)
	local cf = refs.cframe
	local pad = Parts.make({
		Name = name, Parent = refs.model, Color = Color3.fromRGB(60, 60, 70),
		Size = Vector3.new(12, 0.6, 12), CFrame = cf * CFrame.new(x, 0.3, -42),
	})
	pad:SetAttribute("PlotIndex", refs.index)
	Parts.make({
		Name = name .. "Ring", Parent = refs.model, Color = color, Material = Enum.Material.Neon,
		CanCollide = false, Size = Vector3.new(12.4, 0.2, 12.4), CFrame = cf * CFrame.new(x, 0.55, -42),
		Transparency = 0.5,
	})
	local sign = Parts.make({
		Name = name .. "Sign", Parent = refs.model, Color = Color3.fromHex("#1E2A22"),
		Size = Vector3.new(10, 2.4, 0.4), CFrame = cf * CFrame.new(x, 1.8, -48.6),
	})
	Parts.surfaceText(sign, Enum.NormalId.Front, label .. "\n(coming soon)", color)
end

function PlotBuilder.build(index: number, cf: CFrame, parent: Instance): PlotRefs
	local model = Parts.model(`Plot_{index}`, parent)
	model:SetAttribute("PlotIndex", index)

	local ground = Parts.make({
		Name = "Ground", Parent = model, Color = GRASS, Material = Enum.Material.Grass,
		Size = Vector3.new(P.Width, 1, P.Depth), CFrame = cf * CFrame.new(0, -0.5, 0),
	})
	model.PrimaryPart = ground

	local gardenW, gardenD = P.Columns * T, P.Lanes * T
	local midX = P.GardenOriginX + gardenW / 2
	Parts.make({
		Name = "GardenBorder", Parent = model, Color = Color3.fromRGB(110, 74, 44),
		Size = Vector3.new(gardenW + 2, 0.4, gardenD + 2), CFrame = cf * CFrame.new(midX, 0.2, 0),
	})
	Parts.make({
		Name = "ZombieRoad", Parent = model, Color = PATH,
		Size = Vector3.new(P.Width / 2 - (P.GardenOriginX + gardenW) - 1, 0.3, gardenD),
		CFrame = cf * CFrame.new((P.GardenOriginX + gardenW + P.Width / 2) / 2, 0.15, 0),
	})
	Parts.make({
		Name = "FrontPath", Parent = model, Color = PATH,
		Size = Vector3.new(P.Width - 4, 0.3, 10), CFrame = cf * CFrame.new(0, 0.15, -P.Depth / 2 + 8),
	})

	local refs: PlotRefs = {
		index = index,
		cframe = cf,
		model = model,
		tiles = {},
		laneLocks = {},
		houseBase = cf * CFrame.new(P.HouseX, 0, 0),
		house = nil :: any,
		ownerLabel = nil :: any,
		spawn = cf * CFrame.new(P.HouseX, 4, -40),
	}

	local tileFolder = Instance.new("Folder")
	tileFolder.Name = "Tiles"
	tileFolder.Parent = model
	for lane = 1, P.Lanes do
		for col = 1, P.Columns do
			local key = PlotBuilder.tileKey(lane, col)
			local tile = Parts.make({
				Name = "Tile_" .. key, Parent = tileFolder, Color = SOIL,
				Size = Vector3.new(T - 0.6, 0.6, T - 0.6),
				CFrame = cf * CFrame.new(PlotBuilder.colX(col), 0.5, PlotBuilder.laneZ(lane)),
			})
			tile:SetAttribute("PlotIndex", index)
			tile:SetAttribute("Lane", lane)
			tile:SetAttribute("Col", col)
			tile:SetAttribute("TileKey", key)
			refs.tiles[key] = tile
		end
	end

	refs.house = House.build(1, refs.houseBase, model)

	local signAnchor = Parts.make({
		Name = "OwnerSignAnchor", Parent = model, Color = PRIMARY, CanCollide = false, Transparency = 1,
		Size = Vector3.new(1, 1, 1), CFrame = refs.houseBase * CFrame.new(0, 28, 0),
	})
	local bb = Instance.new("BillboardGui")
	bb.Name = "OwnerSign"
	bb.Size = UDim2.fromOffset(260, 56)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 400
	bb.LightInfluence = 0
	bb.Parent = signAnchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromHex("#1E2A22")
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "Empty Plot"
	label.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = PRIMARY
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label
	refs.ownerLabel = label

	buildPad(refs, "NeonMakerPad", "NEON MAKER", -6, Color3.fromRGB(80, 255, 220))
	buildPad(refs, "MegaMakerPad", "MEGA MAKER", 18, Color3.fromRGB(255, 90, 220))

	return refs
end

-- Show lanes > unlocked as locked (grey soil, rope, price sign); unlocked lanes as plain soil.
function PlotBuilder.setLanes(refs: PlotRefs, unlocked: number)
	for lane = 1, P.Lanes do
		local locked = lane > unlocked
		for col = 1, P.Columns do
			local tile = refs.tiles[PlotBuilder.tileKey(lane, col)]
			tile.Color = if locked then SOIL_LOCKED else SOIL
			tile:SetAttribute("Locked", locked)
		end
		local lock = refs.laneLocks[lane]
		if locked and not lock then
			buildLaneLock(refs, lane)
		elseif not locked and lock then
			lock:Destroy()
			refs.laneLocks[lane] = nil
		end
	end
end

function PlotBuilder.setHouseTier(refs: PlotRefs, tier: number)
	if refs.house and refs.house:GetAttribute("Tier") == tier then
		return
	end
	if refs.house then
		refs.house:Destroy()
	end
	refs.house = House.build(tier, refs.houseBase, refs.model)
end

return PlotBuilder
