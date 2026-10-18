--!strict
-- Sky Islands: a cloud meadow with floating islands, cloud puffs and sky pillars.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx)
	ctx.model:SetAttribute("Tint", hx("#EAF6FF"))
	Kit.scatter(ctx, 8, 20, function(cf, rng)
		Kit.island(ctx, cf * CFrame.new(0, rng:NextNumber(18, 34), 0), rng:NextNumber(10, 18), pal.Ground, pal.Prop)
	end)
	Kit.scatter(ctx, 12, 8, function(cf, rng)
		Kit.part(ctx, "Cloud", Vector3.new(8, 4, 6) * rng:NextNumber(0.8, 1.4), cf * CFrame.new(0, 2, 0), pal.Accent1,
			{ Shape = Enum.PartType.Ball, CanCollide = false })
	end)
	Kit.scatter(ctx, 6, 10, function(cf, rng)
		Kit.spire(ctx, cf, 4, rng:NextNumber(10, 18), pal.Accent1, pal.Accent2)
	end)
	Kit.scatter(ctx, 6, 10, function(cf, rng)
		Kit.roundTree(ctx, cf, rng:NextNumber(0.8, 1.1), pal.Ground, pal.Prop)
	end)
end
