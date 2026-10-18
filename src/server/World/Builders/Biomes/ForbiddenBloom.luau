--!strict
-- Forbidden Bloom: blood-dark ground, void pools, obsidian spires and golden roses.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx, nil, Enum.Material.SmoothPlastic)
	ctx.model:SetAttribute("Tint", hx("#FFC8D2"))
	Kit.pool(ctx, Kit.at(ctx, 0, 60), 24, hx("#14000A"), true)
	Kit.scatter(ctx, 10, 12, function(cf, rng)
		Kit.spire(ctx, cf, rng:NextNumber(3, 6), rng:NextNumber(14, 26), hx("#14000A"), pal.Accent1)
	end)
	Kit.scatter(ctx, 12, 6, function(cf, rng)
		Kit.flowers(ctx, cf, rng:NextNumber(1.2, 1.8), pal.Accent1, pal.Accent2)
	end)
	Kit.scatter(ctx, 8, 8, function(cf, rng)
		Kit.glowOrb(ctx, cf, pal.Accent1, rng:NextNumber(3, 8))
	end)
end
