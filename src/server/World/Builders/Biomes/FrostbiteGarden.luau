--!strict
-- Frostbite Garden: snowfield, ice spires, frozen pond and frosted pines.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx, nil, Enum.Material.SmoothPlastic)
	ctx.model:SetAttribute("Tint", hx("#E0F2FF"))
	Kit.pool(ctx, Kit.at(ctx, 45, -10), 22, pal.Accent1)
	Kit.scatter(ctx, 12, 12, function(cf, rng)
		Kit.tree(ctx, cf, rng:NextNumber(0.8, 1.3), hx("#FFFFFF"), pal.Prop)
	end)
	Kit.scatter(ctx, 12, 10, function(cf, rng)
		Kit.crystal(ctx, cf, rng:NextNumber(0.8, 1.8), pal.Accent1)
	end)
	Kit.scatter(ctx, 6, 10, function(cf, rng)
		Kit.hill(ctx, cf, rng:NextNumber(12, 20), rng:NextNumber(2, 4), hx("#FFFFFF"))
	end)
end
