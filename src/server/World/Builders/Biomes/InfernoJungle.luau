--!strict
-- Inferno Jungle: scorched soil, lava pools, burning trees and magma spires.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx, nil, Enum.Material.SmoothPlastic)
	ctx.model:SetAttribute("Tint", hx("#FFC8A8"))
	for _, p in { { -60, 10, 16 }, { 50, 50, 14 }, { 20, -20, 10 } } do
		Kit.pool(ctx, Kit.at(ctx, p[1], p[2]), p[3], pal.Accent1, true)
	end
	Kit.scatter(ctx, 12, 12, function(cf, rng)
		Kit.tree(ctx, cf, rng:NextNumber(0.9, 1.4), pal.Prop, hx("#2B1A12"))
	end)
	Kit.scatter(ctx, 7, 14, function(cf, rng)
		Kit.spire(ctx, cf, rng:NextNumber(4, 7), rng:NextNumber(10, 20), hx("#2B1A12"), pal.Accent1)
	end)
	Kit.scatter(ctx, 8, 8, function(cf, rng)
		Kit.glowOrb(ctx, cf, pal.Accent2, rng:NextNumber(2, 5))
	end)
end
