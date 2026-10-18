--!strict
-- Cactus Canyon: sandy floor, mesas, cacti and desert flowers.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx, nil, Enum.Material.SmoothPlastic)
	ctx.model:SetAttribute("Tint", hx("#FFE2B8"))
	Kit.scatter(ctx, 6, 26, function(cf, rng)
		Kit.spire(ctx, cf, rng:NextNumber(14, 22), rng:NextNumber(14, 26), pal.Accent2, pal.Prop)
	end)
	Kit.scatter(ctx, 16, 8, function(cf, rng)
		Kit.cactus(ctx, cf, rng:NextNumber(0.8, 1.5), pal.Accent1)
	end)
	Kit.scatter(ctx, 8, 6, function(cf, rng)
		Kit.flowers(ctx, cf, rng:NextNumber(0.8, 1.1), hx("#FF8FB1"), hx("#FFD166"))
	end)
	Kit.scatter(ctx, 6, 8, function(cf, rng)
		Kit.rock(ctx, cf, rng:NextNumber(0.7, 1.3), pal.Prop)
	end)
end
