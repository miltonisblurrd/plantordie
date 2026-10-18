--!strict
-- Mushroom Forest: giant mushrooms, glowing fungi, spore orbs on a dusk-purple floor.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx, nil, Enum.Material.SmoothPlastic)
	ctx.model:SetAttribute("Tint", hx("#D8C8FF"))
	Kit.scatter(ctx, 10, 14, function(cf, rng)
		Kit.mushroom(ctx, cf, rng:NextNumber(1.4, 2.2), pal.Accent1, pal.Accent2)
	end)
	Kit.scatter(ctx, 12, 8, function(cf, rng)
		Kit.mushroom(ctx, cf, rng:NextNumber(0.4, 0.7), hx("#7CFFCB"), pal.Accent2, true)
	end)
	Kit.scatter(ctx, 8, 8, function(cf, rng)
		Kit.glowOrb(ctx, cf, hx("#C77DFF"), rng:NextNumber(4, 9))
	end)
	Kit.scatter(ctx, 6, 10, function(cf, rng)
		Kit.rock(ctx, cf, rng:NextNumber(0.8, 1.4), pal.Prop)
	end)
end
