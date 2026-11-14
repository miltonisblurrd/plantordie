--!strict
-- Forbidden Bloom: the last garden. Dark crimson ground veined with gold, colossal glowing flowers,
-- thorned black vines, a sealed bloom shrine at the back wall, and heavy red atmosphere.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local crimson = hx("#FF1E56")
	local gold = hx("#FFD700")
	local thorn = hx("#1A0A0E")
	local stems = hx("#3A1220")
	Kit.ground(ctx, hx("#2B0A12"), Enum.Material.Slate)
	Kit.mood(ctx, { haze = hx("#7A1A30"), decay = hx("#1A0508"), density = 0.42, tint = hx("#FFE0E6"), saturation = 0.22, contrast = 0.16, brightness = -0.04 })
	Kit.patches(ctx, 22, 8, 20, { hx("#3A0E18"), hx("#22070E"), hx("#4A1020") }, Enum.Material.Slate)
	Kit.coreScatter(ctx, 26, function(cf, rng)
		S.crack(ctx, cf, rng:NextNumber(0.8, 1.4), gold)
	end)

	-- Colossal bloom on a dais, back centre-left; shrine of black obelisks, front right.
	local bloom = Kit.landmark(ctx, -1, 0.45, 34)
	Kit.part(ctx, "Dais", Vector3.new(2, 44, 44), bloom * CFrame.new(0, 1, 0) * Kit.UPRIGHT, hx("#1A0A0E"),
		{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate })
	S.giantFlower(ctx, bloom * CFrame.new(0, 2, 0), 2.6, crimson, gold, stems, true)
	local shrine = Kit.landmark(ctx, 1, -0.35, 22)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local h = 20 + (i % 2) * 8
		Kit.part(ctx, "Obelisk", Vector3.new(4, h, 4), shrine * CFrame.new(math.cos(a) * 14, h / 2, math.sin(a) * 14), thorn, { Material = Enum.Material.Basalt })
		Kit.part(ctx, "ObeliskGlow", Vector3.new(4.4, 2, 4.4), shrine * CFrame.new(math.cos(a) * 14, h - 3, math.sin(a) * 14), crimson,
			{ Material = Enum.Material.Neon, Decor = true })
	end
	S.orb(ctx, shrine * CFrame.new(0, 16, 0), 3, gold, true)

	Kit.wallRow(ctx, 16, 7, function(cf, rng, i)
		if i % 3 == 0 then
			S.deadTree(ctx, cf, rng:NextNumber(1.4, 1.9), thorn)
		else
			S.giantFlower(ctx, cf, rng:NextNumber(0.9, 1.3), if i % 2 == 0 then crimson else hx("#B5179E"), gold, stems, i % 7 == 0)
		end
	end)
	Kit.clusters(ctx, 7, 3, 5, 12, function(cf, rng, i)
		if i % 3 == 0 then
			S.rocks(ctx, cf, rng:NextNumber(0.9, 1.3), hx("#2A1418"), Enum.Material.Basalt)
		elseif i % 3 == 1 then
			S.bush(ctx, cf, rng:NextNumber(1, 1.4), hx("#3A0E1A"), crimson)
		else
			S.crystals(ctx, cf, rng:NextNumber(0.6, 0.9), crimson)
		end
	end)
	Kit.coreScatter(ctx, 34, function(cf, rng, i)
		S.flower(ctx, cf, rng:NextNumber(0.9, 1.3), if i % 2 == 0 then crimson else gold)
	end)
	for i = 1, 10 do
		S.orb(ctx, Kit.at(ctx, ctx.rng:NextNumber(-160, 160), ctx.rng:NextNumber(-140, 140)) * CFrame.new(0, ctx.rng:NextNumber(8, 24), 0), 0.6,
			if i % 2 == 0 then crimson else gold)
	end
	Kit.outside(ctx, 12, function(cf, rng, i)
		S.giantFlower(ctx, cf, rng:NextNumber(2.2, 3), if i % 2 == 0 then crimson else hx("#7A0A30"), gold, stems)
	end)
end
