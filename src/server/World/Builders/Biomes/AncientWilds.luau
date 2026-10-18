--!strict
-- Ancient Wilds: prehistoric ferns, giant cycads, fossil bones and boulders.
local Kit = require(script.Parent.Parent.Parent.BiomeKit)

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	Kit.ground(ctx)
	ctx.model:SetAttribute("Tint", hx("#F0EAD6"))
	Kit.scatter(ctx, 14, 8, function(cf, rng)
		Kit.fern(ctx, cf, rng:NextNumber(1.4, 2.4), pal.Accent2)
	end)
	Kit.scatter(ctx, 8, 14, function(cf, rng)
		Kit.palm(ctx, cf, rng:NextNumber(1.2, 1.6), pal.Accent2, pal.Prop)
	end)
	Kit.scatter(ctx, 5, 12, function(cf)
		for i = -1, 1 do
			Kit.part(ctx, "Rib", Vector3.new(1.2, 8, 1.2), cf * CFrame.new(i * 3, 3, 0) * CFrame.Angles(0, 0, 0.5), hx("#E8E0CC"))
		end
	end)
	Kit.scatter(ctx, 8, 10, function(cf, rng)
		Kit.rock(ctx, cf, rng:NextNumber(1, 2), pal.Ground:Lerp(hx("#000000"), 0.2))
	end)
end
