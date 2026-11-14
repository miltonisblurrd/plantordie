--!strict
-- Mushroom Forest: towering toadstools, a glowing fairy ring, twisted trees, mossy logs and spores.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local caps = { hx("#FF4D4D"), hx("#FF8A3D"), hx("#C77DFF"), hx("#FFD166") }
	local stem = hx("#FFF3E0")
	local bark = hx("#5A3D2B")
	Kit.ground(ctx, hx("#4E6B3A"), Enum.Material.Grass)
	Kit.mood(ctx, { haze = hx("#8E6FB8"), decay = hx("#4B2E6B"), density = 0.38, tint = hx("#F2E6FF"), saturation = 0.2, contrast = 0.08 })
	Kit.patches(ctx, 22, 8, 18, { hx("#5E7D45"), hx("#3F5A32"), hx("#6B4F8C") }, Enum.Material.Grass)
	Kit.patches(ctx, 8, 4, 8, { hx("#7A5A9E") }, Enum.Material.Neon, true)

	-- Fairy ring of giant glowing mushrooms around a stump, back right.
	local ring = Kit.landmark(ctx, 1, 0.55, 32)
	S.stump(ctx, ring, 2.2, bark)
	for i = 0, 5 do
		local a = i * math.pi / 3
		S.mushroom(ctx, ring * CFrame.new(math.cos(a) * 20, 0, math.sin(a) * 20), if i % 2 == 0 then 2.4 else 1.8,
			caps[i % #caps + 1], stem, i < 2)
	end
	-- Single colossal toadstool, front left.
	local giant = Kit.landmark(ctx, -1, -0.35, 22)
	S.mushroom(ctx, giant, 5, hx("#E63946"), stem)

	Kit.wallRow(ctx, 18, 7, function(cf, rng, i)
		if i % 3 == 0 then
			S.deadTree(ctx, cf, rng:NextNumber(1.3, 1.8), bark)
		else
			S.mushroom(ctx, cf, rng:NextNumber(1.6, 2.8), caps[i % #caps + 1], stem)
		end
	end)
	Kit.clusters(ctx, 7, 3, 5, 12, function(cf, rng, i)
		if i % 4 == 0 then
			S.log(ctx, cf, rng:NextNumber(1, 1.3), bark, hx("#6FAF4A"))
		elseif i % 4 == 1 then
			S.rocks(ctx, cf, rng:NextNumber(0.8, 1.1), hx("#6E6A80"))
		else
			S.mushroom(ctx, cf, rng:NextNumber(0.9, 1.4), caps[i % #caps + 1], stem)
		end
	end)
	Kit.coreScatter(ctx, 60, function(cf, rng, i)
		if i % 2 == 0 then
			S.mushroomPatch(ctx, cf, rng:NextNumber(0.8, 1.2), caps[i % #caps + 1], stem)
		else
			S.tuft(ctx, cf, rng:NextNumber(0.9, 1.3), hx("#4F7A35"))
		end
	end)
	for i = 1, 10 do
		local x = ctx.rng:NextNumber(-150, 150)
		S.orb(ctx, Kit.at(ctx, x, ctx.rng:NextNumber(-140, 140)) * CFrame.new(0, ctx.rng:NextNumber(8, 18), 0), 0.8,
			if i % 2 == 0 then hx("#C77DFF") else hx("#7CFFCB"))
	end
	Kit.outside(ctx, 14, function(cf, rng, i)
		S.mushroom(ctx, cf, rng:NextNumber(3.5, 5), caps[i % #caps + 1], stem)
	end)
end
