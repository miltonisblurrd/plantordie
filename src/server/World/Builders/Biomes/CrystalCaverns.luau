--!strict
-- Crystal Caverns: dark slate floor, a cavern overhang of rock against the walls, towering glowing
-- crystal clusters in cyan, pink and violet, reflective pools.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local gems = { hx("#5CE1E6"), hx("#FF66C4"), hx("#8A7FFF") }
	local rock = hx("#3B3B58")
	Kit.ground(ctx, hx("#34344E"), Enum.Material.Slate)
	Kit.mood(ctx, { haze = hx("#6A5ACD"), decay = hx("#1C1C3A"), density = 0.45, tint = hx("#E6E8FF"), saturation = 0.2, contrast = 0.14, brightness = -0.03 })
	Kit.patches(ctx, 24, 8, 20, { hx("#2C2C44"), hx("#40405E"), hx("#2A3A50") }, Enum.Material.Slate)
	Kit.patches(ctx, 10, 3, 6, { hx("#5CE1E6"), hx("#FF66C4") }, Enum.Material.Glass, true)

	-- Giant geode cluster, back left, and a rock overhang with hanging crystals, front right.
	local geode = Kit.landmark(ctx, -1, 0.45, 30)
	S.crystals(ctx, geode, 3, gems[1], true)
	S.crystals(ctx, geode * CFrame.new(14, 0, 10), 1.8, gems[2], true)
	local cave = Kit.landmark(ctx, 1, -0.35, 26)
	Kit.part(ctx, "OverhangL", Vector3.new(10, 24, 30), cave * CFrame.new(-14, 12, 0), rock, { Material = Enum.Material.Slate })
	Kit.part(ctx, "OverhangR", Vector3.new(10, 24, 30), cave * CFrame.new(14, 12, 0), rock, { Material = Enum.Material.Slate })
	Kit.part(ctx, "OverhangTop", Vector3.new(40, 8, 34), cave * CFrame.new(0, 27, 0) * CFrame.Angles(0, 0, 0.05), rock:Lerp(Color3.new(0, 0, 0), 0.15),
		{ Material = Enum.Material.Slate })
	for i = -1, 1 do
		Kit.part(ctx, "Stalactite", Vector3.new(3, 9, 3), cave * CFrame.new(i * 7, 19, 0) * CFrame.Angles(math.pi, 0.4, 0), gems[3],
			{ Wedge = true, Material = Enum.Material.Glass, Decor = true })
	end
	S.pond(ctx, cave * CFrame.new(0, 0, -4), 8, hx("#5CE1E6"), rock, true)

	Kit.wallRow(ctx, 16, 7, function(cf, rng, i)
		if i % 3 == 0 then
			S.boulder(ctx, cf, rng:NextNumber(1.1, 1.6), rock)
		else
			S.crystals(ctx, cf, rng:NextNumber(1.3, 2), gems[i % #gems + 1], i % 5 == 0)
		end
	end)
	Kit.clusters(ctx, 7, 3, 5, 12, function(cf, rng, i)
		if i % 2 == 0 then
			S.rocks(ctx, cf, rng:NextNumber(0.9, 1.3), hx("#4A4A6A"))
		else
			S.crystals(ctx, cf, rng:NextNumber(0.7, 1.1), gems[i % #gems + 1])
		end
	end)
	Kit.coreScatter(ctx, 50, function(cf, rng, i)
		S.pebbles(ctx, cf, rng:NextNumber(0.8, 1.3), if i % 3 == 0 then gems[(i % #gems) + 1] else hx("#4A4A66"))
	end)
	Kit.outside(ctx, 12, function(cf, rng, i)
		S.crystals(ctx, cf, rng:NextNumber(3, 4.5), gems[i % #gems + 1])
	end)
end
