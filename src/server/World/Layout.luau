--!strict
-- World placement maths shared by builders and services (server only).
-- Plots sit on a ring at 45-degree steps; biome gates sit two per sector between plot paths
-- (16 slots, 15 used) so no gate ever blocks a plot path. Biome areas sit on an outer ring,
-- reached by paths that pass through the gaps between plots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local W = Config.World
local B = Config.Biome

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

-- The gap between plot s and plot s+1 that both of a sector's gates route through.
function Layout.gapAngle(biomeIndex: number): number
	local step = 360 / W.PlotCount
	return ((biomeIndex - 1) // 2) * step + step / 2
end

function Layout.biomeAngle(biomeIndex: number): number
	local slot = (biomeIndex - 1) % 2
	local step = 360 / W.PlotCount
	return Layout.gapAngle(biomeIndex) + (if slot == 0 then -step / 4 else step / 4)
end

-- Biome centre. -Z faces the hub, so the entrance edge is at local Z = -Size/2.
function Layout.biomeCFrame(biomeIndex: number): CFrame
	local pos = ringPoint(Layout.biomeAngle(biomeIndex), B.RingRadius)
	return CFrame.lookAt(pos, Vector3.new(0, W.GroundY, 0))
end

-- Path waypoints from just outside the gate to the biome entrance. The route turns into the
-- gap between plots inside the plot ring, so it never crosses a plot.
function Layout.biomePath(biomeIndex: number): { Vector3 }
	local gate = Layout.gateAngle(biomeIndex)
	local gap = Layout.gapAngle(biomeIndex)
	local inner = W.PlotRingRadius - Config.Plot.Depth / 2 - 55
	local outer = W.PlotRingRadius + Config.Plot.Depth / 2 + 60
	local entrance = (Layout.biomeCFrame(biomeIndex) * CFrame.new(0, 0, -B.Size / 2)).Position
	return {
		ringPoint(gate, W.GateRingRadius + 6),
		ringPoint(gate, inner),
		ringPoint(gap, inner),
		ringPoint(gap, outer),
		entrance,
	}
end

return Layout
