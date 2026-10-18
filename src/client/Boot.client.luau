--!strict
-- Client entry point. Each controller owns one concern; State is the only inbound data path.

local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)
local Hud = require(script.Parent.Hud)
local CameraController = require(script.Parent.Camera)
local Gates = require(script.Parent.Gates)

Notifications.start()
Hud.start()
CameraController.start()
Gates.start()
State.start()
