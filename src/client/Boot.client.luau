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

local barGui = Ui.screen("ActionBar", Players.LocalPlayer:WaitForChild("PlayerGui"), 2)
-- Scrolls sideways when the buttons are wider than the screen; centred when they fit. The
-- right gap keeps clear of the Lane View button.
local bar = Instance.new("ScrollingFrame")
bar.Name = "Bar"
bar.BackgroundTransparency = 1
bar.BorderSizePixel = 0
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, -60, 1, -8)
bar.Size = UDim2.new(1, -220, 0, 80)
bar.ScrollingDirection = Enum.ScrollingDirection.X
bar.AutomaticCanvasSize = Enum.AutomaticSize.X
bar.CanvasSize = UDim2.new()
bar.ScrollBarThickness = 4
bar.VerticalScrollBarInset = Enum.ScrollBarInset.None
bar.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
bar.Parent = barGui
local barLimit = Instance.new("UISizeConstraint")
barLimit.MaxSize = Vector2.new(820, 80)
barLimit.Parent = bar
local barList = Ui.list(bar, Enum.FillDirection.Horizontal, 10)
barList.HorizontalAlignment = Enum.HorizontalAlignment.Center
barList.VerticalAlignment = Enum.VerticalAlignment.Center

Sfx.start()
Effects.start()
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
Purchases.start()
FusionPanel.start()
Collection.start(bar)
EventShop.start(bar)
SettingsPanel.start(bar)
Feedback.start()
State.start()
