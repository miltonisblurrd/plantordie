--!strict
-- Inferno Jungle: dark basalt ground split by lava cracks, a smoking volcano, charred jungle trees.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local lava = hx("#FF5A1F")
	local leaves = { hx("#1F7A3A"), hx("#2C8C3C"), hx("#3C6B22") }
	local bark = hx("#2A1E18")
	Kit.ground(ctx, hx("#3D2B1F"), Enum.Material.Basalt)
	Kit.mood(ctx, { haze = hx("#FF8A4C"), decay = hx("#5A1A0A"), density = 0.4, tint = hx("#FFE2CC"), saturation = 0.2, contrast = 0.12 })
	Kit.patches(ctx, 22, 8, 18, { hx("#2E211A"), hx("#4A3326"), hx("#26201E") }, Enum.Material.Basalt)
	Kit.patches(ctx, 8, 6, 12, { hx("#2C5E2A") }, Enum.Material.Grass)

	S.volcano(ctx, Kit.landmark(ctx, -1, 0.5, 34), 1.3, hx("#2B2422"), lava)
	local pool = Kit.landmark(ctx, 1, -0.3, 20)
	S.pond(ctx, pool, 16, lava, hx("#2B2422"), true)

	Kit.wallRow(ctx, 19, 7, function(cf, rng, i)
		if i % 3 == 0 then
			S.deadTree(ctx, cf, rng:NextNumber(1.3, 1.7), bark)
		else
			S.umbrellaTree(ctx, cf, rng:NextNumber(1, 1.4), leaves[i % #leaves + 1], hx("#4A3428"))
		end
	end)
	Kit.clusters(ctx, 7, 3, 5, 13, function(cf, rng, i)
		if i % 2 == 0 then
			S.rocks(ctx, cf, rng:NextNumber(0.9, 1.4), hx("#2B2422"), Enum.Material.Basalt)
		else
			S.bush(ctx, cf, rng:NextNumber(1, 1.4), leaves[i % #leaves + 1], hx("#FFC300"))
		end
	end)
	Kit.coreScatter(ctx, 40, function(cf, rng, i)
		if i % 2 == 0 then
			S.crack(ctx, cf, rng:NextNumber(0.9, 1.6), lava)
		else
			S.pebbles(ctx, cf, rng:NextNumber(0.9, 1.3), hx("#1E1715"))
		end
	end)
	Kit.outside(ctx, 12, function(cf, rng, i)
		if i % 3 == 0 then
			S.volcano(ctx, cf, rng:NextNumber(0.7, 1), hx("#2B2422"), lava)
		else
			S.umbrellaTree(ctx, cf, rng:NextNumber(1.6, 2.2), leaves[1], bark)
		end
	end)
end
