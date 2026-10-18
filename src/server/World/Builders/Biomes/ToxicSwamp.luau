--!strict
-- Toxic Swamp: murky floor, glowing sludge pools, dead trees and poison mushrooms.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx, nil, Enum.Material.SmoothPlastic)
	ctx.model:SetAttribute("Tint", hx("#D8F0B0"))
	for _, p in { { -50, 30, 18 }, { 55, -5, 16 }, { 10, 70, 14 } } do
		Kit.pool(ctx, Kit.at(ctx, p[1], p[2]), p[3], pal.Accent1, true)
	end
	Kit.scatter(ctx, 10, 12, function(cf, rng)
		Kit.spire(ctx, cf, 1.8, rng:NextNumber(10, 16), pal.Prop, pal.Accent2)
	end)
	Kit.scatter(ctx, 12, 8, function(cf, rng)
		Kit.mushroom(ctx, cf, rng:NextNumber(0.6, 1.2), pal.Accent2, hx("#C9D99C"), rng:NextNumber() < 0.4)
	end)
	Kit.scatter(ctx, 6, 8, function(cf, rng)
		Kit.glowOrb(ctx, cf, pal.Accent1, rng:NextNumber(2, 4))
	end)
end
