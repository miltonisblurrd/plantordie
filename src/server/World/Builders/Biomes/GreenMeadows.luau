--!strict
-- Green Meadows: rolling grass edges, mixed oaks, flower meadows, a pond and a hilltop windmill.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local pal = ctx.pal
	local leaves = { hx("#3E8E41"), hx("#4FB548"), hx("#2F7A3A"), hx("#6CC24A") }
	local trunk = hx("#7A5032")
	Kit.ground(ctx, hx("#5BC453"), Enum.Material.Grass)
	Kit.mood(ctx, { haze = hx("#CFEFFF"), decay = hx("#9FD3FF"), density = 0.25, tint = hx("#FFFDF2"), saturation = 0.15 })
	Kit.patches(ctx, 26, 8, 20, { hx("#6BD25F"), hx("#4EAE46"), hx("#7FDB6A") }, Enum.Material.Grass)
	Kit.patches(ctx, 6, 5, 9, { hx("#A57C52") }, Enum.Material.Ground)

	-- Windmill on a grassy rise, back left.
	local mill = Kit.landmark(ctx, -1, 0.6, 30)
	Kit.mound(ctx, mill, 52, 6, hx("#58BE4E"))
	Kit.part(ctx, "MillTower", Vector3.new(10, 26, 10), mill * CFrame.new(0, 15, 0), hx("#F2E8D5"), { Material = Enum.Material.WoodPlanks })
	Kit.part(ctx, "MillRoof", Vector3.new(12, 7, 12), mill * CFrame.new(0, 31.5, 0) * CFrame.Angles(0, math.rad(45), 0), hx("#C0392B"))
	for i = 0, 3 do
		Kit.part(ctx, "Sail", Vector3.new(2.5, 18, 0.6), mill * CFrame.new(-6, 26, 0) * CFrame.Angles(0, math.pi / 2, i * math.pi / 2) * CFrame.new(0, 9, 0), hx("#FFF7E6"))
	end
	S.fence(ctx, mill * CFrame.new(16, 0, 10) * CFrame.Angles(0, 0.3, 0), 1, hx("#A86A32"), 24)

	-- Pond with lily colour, front right.
	local pond = Kit.landmark(ctx, 1, -0.45, 24)
	S.pond(ctx, pond, 20, hx("#5AB8FF"), hx("#9AA3A8"))
	S.log(ctx, pond * CFrame.new(-14, 0, -18) * CFrame.Angles(0, 0.8, 0), 1, trunk, hx("#4FB548"))

	Kit.wallRow(ctx, 20, 7, function(cf, rng, i)
		local leaf = leaves[i % #leaves + 1]
		if i % 3 == 0 then
			S.roundTree(ctx, cf, rng:NextNumber(1.2, 1.7), leaf, trunk)
		else
			S.blockTree(ctx, cf, rng:NextNumber(1.2, 1.8), leaf, trunk)
		end
	end)
	Kit.clusters(ctx, 6, 3, 5, 14, function(cf, rng, i)
		if i % 3 == 0 then
			S.rocks(ctx, cf, rng:NextNumber(0.8, 1.3), hx("#9AA3A8"))
		else
			S.bush(ctx, cf, rng:NextNumber(0.9, 1.4), leaves[i % #leaves + 1], if i % 2 == 0 then pal.Accent2 else nil)
		end
	end)
	Kit.edgeScatter(ctx, 6, 6, function(cf, rng)
		S.roundTree(ctx, cf, rng:NextNumber(0.9, 1.2), leaves[2], trunk)
	end)
	Kit.edgeScatter(ctx, 4, 6, function(cf, rng)
		S.log(ctx, cf, rng:NextNumber(0.9, 1.2), trunk, leaves[2])
	end)
	Kit.coreScatter(ctx, 70, function(cf, rng, i)
		if i % 3 == 0 then
			S.tuft(ctx, cf, rng:NextNumber(0.9, 1.4), hx("#3FA33A"))
		else
			S.flower(ctx, cf, rng:NextNumber(0.8, 1.2), if i % 2 == 0 then pal.Accent1 else pal.Accent2)
		end
	end)
	Kit.outside(ctx, 14, function(cf, rng, i)
		S.roundTree(ctx, cf, rng:NextNumber(2, 2.8), leaves[i % #leaves + 1], trunk)
	end)
end
