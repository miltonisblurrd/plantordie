--!strict
-- Client entry point. Each controller owns one concern; State is the only inbound data path.

local Players = game:GetService("Players")

local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)
local Notifications = require(script.Parent.Notifications)
local Hud = require(script.Parent.Hud)
local CameraController = require(script.Parent.Camera)
local Gates = require(script.Parent.Gates)
local Placement = require(script.Parent.Placement)
local Inspect = require(script.Parent.Inspect)
local Inventory = require(script.Parent.Inventory)
local Shops = require(script.Parent.Shops)
local GardenView = require(script.Parent.GardenView)
local Danger = require(script.Parent.Danger)
local Shovel = require(script.Parent.Shovel)
local Atmosphere = require(script.Parent.Atmosphere)
local Defense = require(script.Parent.Defense)
local Purchases = require(script.Parent.Purchases)
local FusionPanel = require(script.Parent.FusionPanel)
local EventShop = require(script.Parent.EventShop)
local Collection = require(script.Parent.Collection)
local Sfx = require(script.Parent.Sfx)
local Effects = require(script.Parent.Effects)
local Feedback = require(script.Parent.Feedback)
local SettingsPanel = require(script.Parent.SettingsPanel)
local Treadmill = require(script.Parent.Treadmill)
local ShopStalls = require(script.Parent.ShopStalls)
local TrailFx = require(script.Parent.TrailFx)
local BiomeBanner = require(script.Parent.BiomeBanner)

local barGui = Ui.screen("ActionBar", Players.LocalPlayer:WaitForChild("PlayerGui"), 2)

local function side(name: string, anchorX: number, posX: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(anchorX, 0.5)
	f.Position = UDim2.new(posX, if anchorX == 0 then 8 else -8, 0.5, 0)
	f.Size = UDim2.fromOffset(140, 460)
	f.Parent = barGui
	local list = Ui.list(f, Enum.FillDirection.Vertical, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	return f
end

local left = side("Left", 0, 0)
local right = side("Right", 1, 1)

Sfx.start()
Effects.start()
Notifications.start()
Hud.start()
CameraController.start()
Gates.start()
Placement.start()
Inspect.start()
Placement.setInspectHandler(Inspect.open)
Inventory.start(left, right)
Shops.start(left)
GardenView.start()
Danger.start()
Shovel.start()
Atmosphere.start()
Defense.start()
Purchases.start()
FusionPanel.start()
Collection.start(right)
EventShop.start(right)
SettingsPanel.start(right)
Feedback.start()
Treadmill.start()
ShopStalls.start()
TrailFx.start()
BiomeBanner.start()
State.start()
