--!strict
-- World placement maths shared by builders and services (server only).
-- Plots sit on a ring at 45-degree steps; biome gates sit two per sector between plot paths
-- (16 slots, 15 used) so no gate ever blocks a plot path.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local W = Config.World

local Layout = {}

local function ringPoint(angleDeg: number, radius: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a) * radius, W.GroundY, math.sin(a) * radius)
end

function Layout.plotAngle(index: number): number
	return (index - 1) * (360 / W.PlotCount)
end

-- Plot CFrame: -Z faces the hub.
function Layout.plotCFrame(index: number): CFrame
	local pos = ringPoint(Layout.plotAngle(index), W.PlotRingRadius)
	return CFrame.lookAt(pos, Vector3.new(0, W.GroundY, 0))
end

function Layout.gateAngle(biomeIndex: number): number
	local sector = (biomeIndex - 1) // 2
	local slot = (biomeIndex - 1) % 2
	local step = 360 / W.PlotCount
	return sector * step + step * (slot + 1) / 3
end

-- Gate CFrame: -Z faces outward, away from the hub.
function Layout.gateCFrame(biomeIndex: number): CFrame
	local angle = Layout.gateAngle(biomeIndex)
	local pos = ringPoint(angle, W.GateRingRadius)
	return CFrame.lookAt(pos, pos + ringPoint(angle, 1))
end

function Layout.biomeAnchor(biomeIndex: number): CFrame
	local angle = Layout.gateAngle(biomeIndex)
	local pos = ringPoint(angle, W.BiomeAnchorRadius)
	return CFrame.lookAt(pos, Vector3.new(0, W.GroundY, 0))
end

return Layout
