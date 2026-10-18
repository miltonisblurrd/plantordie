--!strict
-- Autumn Woods: orange forest floor, maple trees, pumpkins and leaf piles.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx)
	ctx.model:SetAttribute("Tint", hx("#FFE0C0"))
	Kit.scatter(ctx, 14, 12, function(cf, rng, i)
		Kit.tree(ctx, cf, rng:NextNumber(0.9, 1.4), if i % 2 == 0 then pal.Accent1 else pal.Accent2, pal.Prop)
	end)
	Kit.scatter(ctx, 10, 6, function(cf, rng)
		Kit.part(ctx, "Pumpkin", Vector3.new(3, 2.4, 3) * rng:NextNumber(0.8, 1.5), cf * CFrame.new(0, 1, 0), hx("#FF7518"), { Shape = Enum.PartType.Ball })
	end)
	Kit.scatter(ctx, 6, 10, function(cf, rng)
		Kit.hill(ctx, cf, rng:NextNumber(8, 12), 1.5, pal.Accent1)
	end)
end
