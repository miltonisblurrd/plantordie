--!strict
-- Cactus Canyon: layered sandstone mesas, a natural rock arch, saguaros, dry brush and bleached rocks.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local stone = { hx("#C9733E"), hx("#D98A4E"), hx("#E4A565"), hx("#EDBE80") }
	local green = { hx("#3FA34D"), hx("#4F9A3E"), hx("#2E8B57") }
	Kit.ground(ctx, hx("#E8B86D"), Enum.Material.Sand)
	Kit.mood(ctx, { haze = hx("#F6D7A7"), decay = hx("#E8A060"), density = 0.32, tint = hx("#FFF1DC"), saturation = 0.12, contrast = 0.08 })
	Kit.patches(ctx, 24, 8, 22, { hx("#DDA55C"), hx("#F0C784"), hx("#D49352") }, Enum.Material.Sand)
	Kit.patches(ctx, 10, 6, 12, { hx("#C88A55") }, Enum.Material.Sandstone)

	-- Two big mesas and a stone arch along the canyon walls.
	S.mesa(ctx, Kit.landmark(ctx, -1, 0.5, 30), 50, 34, stone)
	S.mesa(ctx, Kit.landmark(ctx, 1, -0.4, 26), 44, 26, { stone[2], stone[3], stone[4] })
	S.arch(ctx, Kit.landmark(ctx, 1, 0.65, 18), 1.4, hx("#D98A4E"), Enum.Material.Sandstone)

	Kit.wallRow(ctx, 26, 8, function(cf, rng, i)
		if i % 2 == 0 then
			S.mesa(ctx, cf, rng:NextNumber(14, 20), rng:NextNumber(12, 22), { stone[1], stone[3] })
		else
			S.cactus(ctx, cf, rng:NextNumber(1.3, 1.9), green[i % #green + 1], hx("#FF6F91"))
		end
	end)
	Kit.clusters(ctx, 7, 3, 5, 14, function(cf, rng, i)
		if i % 3 == 0 then
			S.rocks(ctx, cf, rng:NextNumber(0.9, 1.4), hx("#C98B5A"), Enum.Material.Sandstone)
		elseif i % 3 == 1 then
			S.cactus(ctx, cf, rng:NextNumber(0.9, 1.3), green[i % #green + 1], if i % 2 == 0 then hx("#FFD166") else nil)
		else
			S.barrelCactus(ctx, cf, rng:NextNumber(0.9, 1.3), green[2], hx("#FF6F91"))
		end
	end)
	Kit.edgeScatter(ctx, 5, 5, function(cf, rng)
		S.deadTree(ctx, cf, rng:NextNumber(0.7, 1), hx("#9C7A5B"))
	end)
	Kit.coreScatter(ctx, 50, function(cf, rng, i)
		if i % 2 == 0 then
			S.pebbles(ctx, cf, rng:NextNumber(0.8, 1.3), hx("#B98455"))
		else
			S.tuft(ctx, cf, rng:NextNumber(0.8, 1.2), hx("#B8A054"))
		end
	end)
	Kit.outside(ctx, 12, function(cf, rng)
		S.mesa(ctx, cf, rng:NextNumber(30, 50), rng:NextNumber(40, 60), stone)
	end)
end
