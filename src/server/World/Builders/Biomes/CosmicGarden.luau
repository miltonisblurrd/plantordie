--!strict
-- Cosmic Garden: starry void floor, alien flowers, star orbs and orbiting rocks.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx, nil, Enum.Material.SmoothPlastic)
	ctx.model:SetAttribute("Tint", hx("#C8B8FF"))
	Kit.scatter(ctx, 14, 6, function(cf, rng)
		Kit.glowOrb(ctx, cf, if rng:NextNumber() < 0.5 then pal.Accent1 else pal.Accent2, rng:NextNumber(4, 20))
	end)
	Kit.scatter(ctx, 10, 10, function(cf, rng)
		Kit.mushroom(ctx, cf, rng:NextNumber(0.8, 1.6), pal.Accent2, pal.Prop, true)
	end)
	Kit.scatter(ctx, 6, 16, function(cf, rng)
		Kit.island(ctx, cf * CFrame.new(0, rng:NextNumber(16, 30), 0), rng:NextNumber(6, 12), pal.Prop, pal.Ground)
	end)
	Kit.scatter(ctx, 8, 8, function(cf, rng)
		Kit.crystal(ctx, cf, rng:NextNumber(0.8, 1.4), pal.Accent1, true)
	end)
end
