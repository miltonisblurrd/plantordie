--!strict
-- Autumn Woods: orange, red and gold trees, leaf piles, fallen logs, a woodcutter's cabin with a
-- fenced yard and warm low sun.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local leaves = { hx("#FF8C00"), hx("#C0392B"), hx("#E8B33A"), hx("#D9572B") }
	local bark = hx("#5A3A26")
	local wood = hx("#8B5A34")
	Kit.ground(ctx, hx("#A9864A"), Enum.Material.Grass)
	Kit.mood(ctx, { haze = hx("#FFD6A0"), decay = hx("#C0703A"), density = 0.32, tint = hx("#FFF0DC"), saturation = 0.2, contrast = 0.08 })
	Kit.patches(ctx, 26, 8, 20, { hx("#C27A2E"), hx("#9C6B36"), hx("#B5651D"), hx("#8E7A3E") }, Enum.Material.LeafyGrass)

	-- Cabin, back right.
	local cabin = Kit.landmark(ctx, 1, 0.5, 26)
	Kit.part(ctx, "CabinBody", Vector3.new(20, 12, 16), cabin * CFrame.new(0, 6, 0), wood, { Material = Enum.Material.WoodPlanks })
	for _, side in { -1, 1 } do
		Kit.part(ctx, "CabinRoof", Vector3.new(22, 2, 11), cabin * CFrame.new(0, 15, side * 4.5) * CFrame.Angles(side * 0.55, 0, 0), hx("#7A2E1E"))
	end
	Kit.part(ctx, "Chimney", Vector3.new(3, 10, 3), cabin * CFrame.new(6, 18, 3), hx("#7A7470"), { Material = Enum.Material.Brick })
	Kit.part(ctx, "Door", Vector3.new(4, 7, 0.4), cabin * CFrame.new(0, 3.5, -8.1), hx("#4A2E1C"))
	S.fence(ctx, cabin * CFrame.new(0, 0, -16), 1, wood, 26)
	S.lantern(ctx, cabin * CFrame.new(-12, 0, -12), 1, bark, hx("#FFB347"))
	-- Giant golden tree, front left.
	S.giantTree(ctx, Kit.landmark(ctx, -1, -0.3, 30), 1.2, leaves[3], bark)

	Kit.wallRow(ctx, 18, 7, function(cf, rng, i)
		local leaf = leaves[i % #leaves + 1]
		if i % 3 == 0 then
			S.pine(ctx, cf, rng:NextNumber(1.2, 1.6), leaf, bark)
		elseif i % 3 == 1 then
			S.roundTree(ctx, cf, rng:NextNumber(1.3, 1.8), leaf, bark)
		else
			S.blockTree(ctx, cf, rng:NextNumber(1.3, 1.8), leaf, bark)
		end
	end)
	Kit.clusters(ctx, 7, 3, 5, 13, function(cf, rng, i)
		if i % 3 == 0 then
			S.log(ctx, cf, rng:NextNumber(1, 1.3), bark)
		elseif i % 3 == 1 then
			S.stump(ctx, cf, rng:NextNumber(1, 1.4), bark)
		else
			S.rocks(ctx, cf, rng:NextNumber(0.8, 1.1), hx("#8A8378"))
		end
	end)
	Kit.coreScatter(ctx, 60, function(cf, rng, i)
		S.leafPile(ctx, cf, rng:NextNumber(0.8, 1.4), leaves[i % #leaves + 1], leaves[(i + 1) % #leaves + 1])
	end)
	Kit.outside(ctx, 14, function(cf, rng, i)
		S.roundTree(ctx, cf, rng:NextNumber(2.2, 3), leaves[i % #leaves + 1], bark)
	end)
end
