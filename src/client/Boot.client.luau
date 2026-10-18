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

local barGui = Ui.screen("ActionBar", Players.LocalPlayer:WaitForChild("PlayerGui"), 2)
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.BackgroundTransparency = 1
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -12)
bar.Size = UDim2.fromOffset(380, 52)
bar.Parent = barGui
Ui.list(bar, Enum.FillDirection.Horizontal, 10).HorizontalAlignment = Enum.HorizontalAlignment.Center

Notifications.start()
Hud.start()
CameraController.start()
Gates.start()
Placement.start()
Inspect.start()
Placement.setInspectHandler(Inspect.open)
Inventory.start(bar)
Shops.start(bar)
GardenView.start()
Danger.start()
Shovel.start(bar)
Atmosphere.start()
Defense.start()
State.start()
