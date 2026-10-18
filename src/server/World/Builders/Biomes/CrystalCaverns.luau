--!strict
-- Crystal Caverns: dark cave floor, glowing crystal clusters and stalagmites.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx, nil, Enum.Material.SmoothPlastic)
	ctx.model:SetAttribute("Tint", hx("#C8D2FF"))
	Kit.scatter(ctx, 18, 8, function(cf, rng, i)
		Kit.crystal(ctx, cf, rng:NextNumber(0.8, 2), if i % 3 == 0 then pal.Accent2 else pal.Accent1, true)
	end)
	Kit.scatter(ctx, 10, 10, function(cf, rng)
		Kit.spire(ctx, cf, rng:NextNumber(3, 5), rng:NextNumber(8, 16), pal.Prop:Lerp(pal.Ground, 0.5), pal.Prop)
	end)
	Kit.scatter(ctx, 6, 10, function(cf, rng)
		Kit.rock(ctx, cf, rng:NextNumber(0.8, 1.4), pal.Ground:Lerp(hx("#FFFFFF"), 0.15))
	end)
end
