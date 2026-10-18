--!strict
-- Enchanted Grove: twilight forest with magic orbs, moon flowers and rune stones.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx)
	ctx.model:SetAttribute("Tint", hx("#E4D2FF"))
	Kit.scatter(ctx, 12, 12, function(cf, rng)
		Kit.roundTree(ctx, cf, rng:NextNumber(0.9, 1.4), pal.Accent1:Lerp(pal.Prop, 0.5), pal.Prop)
	end)
	Kit.scatter(ctx, 10, 8, function(cf, rng)
		Kit.glowOrb(ctx, cf, if rng:NextNumber() < 0.5 then pal.Accent1 else pal.Accent2, rng:NextNumber(5, 10))
	end)
	Kit.scatter(ctx, 12, 6, function(cf, rng)
		Kit.flowers(ctx, cf, rng:NextNumber(1, 1.4), hx("#F0E6FF"), pal.Accent2)
	end)
	Kit.scatter(ctx, 5, 10, function(cf, rng)
		Kit.spire(ctx, cf, 3, rng:NextNumber(6, 10), pal.Prop, pal.Accent2)
	end)
end
