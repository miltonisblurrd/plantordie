--!strict
-- Tropical Paradise: sandy edges, a turquoise lagoon with a palm island, curved palms, giant
-- tropical leaves, a tiki hut and bright flowers.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	local fronds = { hx("#2DAA4F"), hx("#3CC060"), hx("#1F8F45") }
	local trunk = hx("#A07850")
	Kit.ground(ctx, hx("#7DD36A"), Enum.Material.Grass)
	Kit.mood(ctx, { haze = hx("#BFF4FF"), decay = hx("#5FD0E0"), density = 0.22, tint = hx("#FFFBEA"), saturation = 0.22 })
	-- Sand runs along both edges and spills into the floor.
	for _, side in { -1, 1 } do
		Kit.decor(ctx, function()
			Kit.part(ctx, "Beach", Vector3.new(66, 0.2, ctx.length), Kit.at(ctx, side * (ctx.width / 2 - 33), 0) * CFrame.new(0, Kit.FLOOR_TOP + 0.05, 0),
				hx("#F7E1A0"), { Material = Enum.Material.Sand, Parent = ctx.model })
		end)
	end
	Kit.patches(ctx, 20, 8, 18, { hx("#F2D68C"), hx("#8EDB74"), hx("#6CC85E") }, Enum.Material.Sand)

	local lagoon = Kit.landmark(ctx, -1, 0.4, 32)
	S.pond(ctx, lagoon, 28, hx("#3CD6D0"), hx("#E8D3A0"))
	S.palm(ctx, lagoon * CFrame.new(4, 0, 0), 1.6, fronds[1], trunk)
	-- Tiki hut, front right.
	local hut = Kit.landmark(ctx, 1, -0.4, 18)
	for _, c in { { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } } do
		Kit.part(ctx, "HutPost", Vector3.new(1.4, 10, 1.4), hut * CFrame.new(c[1], 5, c[2]), trunk, { Material = Enum.Material.Wood })
	end
	Kit.part(ctx, "HutRoof", Vector3.new(18, 6, 18), hut * CFrame.new(0, 12, 0) * CFrame.Angles(0, math.rad(45), 0), hx("#D9B26A"), { Material = Enum.Material.Fabric })
	Kit.part(ctx, "HutRoofTop", Vector3.new(10, 4, 10), hut * CFrame.new(0, 16, 0) * CFrame.Angles(0, math.rad(45), 0), hx("#C49A50"), { Material = Enum.Material.Fabric })
	S.lantern(ctx, hut * CFrame.new(10, 0, 10), 1, trunk, hx("#FFB347"))

	Kit.wallRow(ctx, 17, 7, function(cf, rng, i)
		S.palm(ctx, cf, rng:NextNumber(1.1, 1.6), fronds[i % #fronds + 1], trunk)
	end)
	Kit.clusters(ctx, 7, 3, 5, 13, function(cf, rng, i)
		if i % 3 == 0 then
			S.rocks(ctx, cf, rng:NextNumber(0.8, 1.1), hx("#BFAF90"), Enum.Material.Sandstone)
		elseif i % 3 == 1 then
			S.giantFlower(ctx, cf, rng:NextNumber(0.6, 0.8), if i % 2 == 0 then pal.Accent2 else hx("#FF9F1C"), hx("#FFE066"), fronds[3])
		else
			S.bush(ctx, cf, rng:NextNumber(1.1, 1.5), fronds[2], pal.Accent2)
		end
	end)
	Kit.coreScatter(ctx, 60, function(cf, rng, i)
		if i % 3 == 0 then
			S.flower(ctx, cf, rng:NextNumber(0.9, 1.3), if i % 2 == 0 then pal.Accent2 else hx("#FFE066"))
		else
			S.tuft(ctx, cf, rng:NextNumber(0.9, 1.4), hx("#4FBF52"))
		end
	end)
	Kit.outside(ctx, 14, function(cf, rng, i)
		S.palm(ctx, cf, rng:NextNumber(2, 2.6), fronds[i % #fronds + 1], trunk)
	end)
end
