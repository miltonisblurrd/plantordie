--!strict
-- Green Meadows: rolling grass hills, flower patches, oak trees and a pond.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx)
	Kit.pool(ctx, Kit.at(ctx, -55, 40), 18, hx("#5AB8FF"))
	Kit.scatter(ctx, 5, 30, function(cf, rng)
		Kit.hill(ctx, cf, rng:NextNumber(16, 26), rng:NextNumber(3, 5), pal.Ground:Lerp(hx("#FFFFFF"), 0.08))
	end)
	Kit.scatter(ctx, 12, 12, function(cf, rng)
		Kit.tree(ctx, cf, rng:NextNumber(0.8, 1.3), pal.Prop)
	end)
	Kit.scatter(ctx, 14, 6, function(cf, rng, i)
		Kit.flowers(ctx, cf, rng:NextNumber(0.9, 1.3), if i % 2 == 0 then pal.Accent1 else pal.Accent2, hx("#FFFFFF"))
	end)
end
