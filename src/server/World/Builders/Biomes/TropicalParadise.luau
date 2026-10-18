--!strict
-- Tropical Paradise: sand, lagoon, palm trees and hibiscus bushes.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx, nil, Enum.Material.SmoothPlastic)
	ctx.model:SetAttribute("Tint", hx("#FFF6DC"))
	Kit.pool(ctx, Kit.at(ctx, 0, 50), 30, pal.Accent1)
	Kit.scatter(ctx, 14, 10, function(cf, rng)
		Kit.palm(ctx, cf, rng:NextNumber(0.9, 1.3), pal.Prop, hx("#A0522D"))
	end)
	Kit.scatter(ctx, 10, 6, function(cf, rng)
		Kit.flowers(ctx, cf, rng:NextNumber(1, 1.4), pal.Accent2, hx("#FFE135"))
	end)
	Kit.scatter(ctx, 5, 8, function(cf, rng)
		Kit.rock(ctx, cf, rng:NextNumber(0.6, 1), hx("#D9C08C"))
	end)
end
