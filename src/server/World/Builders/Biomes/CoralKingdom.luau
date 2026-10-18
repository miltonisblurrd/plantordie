--!strict
-- Coral Kingdom: seabed blue, coral reefs, kelp and bubbles.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx, nil, Enum.Material.SmoothPlastic)
	ctx.model:SetAttribute("Tint", hx("#C4E6FF"))
	Kit.scatter(ctx, 14, 10, function(cf, rng, i)
		Kit.coral(ctx, cf, rng:NextNumber(0.9, 1.6), if i % 2 == 0 then pal.Accent1 else pal.Accent2)
	end)
	Kit.scatter(ctx, 10, 8, function(cf, rng)
		Kit.spire(ctx, cf, 1.2, rng:NextNumber(8, 14), hx("#2E8B57"))
	end)
	Kit.scatter(ctx, 10, 8, function(cf, rng)
		Kit.glowOrb(ctx, cf, hx("#E8F6FF"), rng:NextNumber(3, 12))
	end)
	Kit.scatter(ctx, 5, 10, function(cf, rng)
		Kit.rock(ctx, cf, rng:NextNumber(0.8, 1.3), pal.Prop)
	end)
end
