--!strict
-- Sky Islands: a cloud-top meadow with floating islands overhead, cloud banks against the walls,
-- tall rock spires, a sky temple of white columns and pale blue light.
-- The floor stays one level; the islands are scenery only.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local grass = hx("#9FE870")
	local rock = hx("#C2B280")
	local leaves = { hx("#6CCB5F"), hx("#8EE07A") }
	Kit.ground(ctx, grass, Enum.Material.Grass)
	Kit.mood(ctx, { haze = hx("#E8F6FF"), decay = hx("#A8D8FF"), density = 0.3, tint = hx("#F4FBFF"), saturation = 0.08, brightness = 0.04 })
	Kit.patches(ctx, 26, 8, 22, { hx("#FFFFFF"), hx("#EAF6FF"), hx("#B4F08C") }, Enum.Material.SmoothPlastic)

	-- Sky temple: ring of white columns with a floating crown.
	local temple = Kit.landmark(ctx, -1, 0.45, 26)
	Kit.part(ctx, "TempleFloor", Vector3.new(1.2, 40, 40), temple * CFrame.new(0, 0.6, 0) * Kit.UPRIGHT, hx("#F4F4F8"),
		{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Marble })
	for i = 0, 5 do
		local a = i * math.pi / 3
		S.pillar(ctx, temple * CFrame.new(math.cos(a) * 15, 1.2, math.sin(a) * 15), 1, hx("#FFFFFF"))
	end
	S.floatingIsland(ctx, temple * CFrame.new(0, 34, 0), 18, grass, rock, leaves[1])
	-- Rock spires topped with grass, front right.
	local spires = Kit.landmark(ctx, 1, -0.4, 22)
	for i = 0, 2 do
		local h = 26 + i * 10
		Kit.part(ctx, "Spire", Vector3.new(9 - i, h, 9 - i), spires * CFrame.new(-8 + i * 8, h / 2, (i % 2) * 7) * CFrame.Angles(0, i, 0), rock,
			{ Material = Enum.Material.Slate })
		Kit.part(ctx, "SpireTop", Vector3.new(11 - i, 2, 11 - i), spires * CFrame.new(-8 + i * 8, h + 1, (i % 2) * 7) * CFrame.Angles(0, i, 0), grass,
			{ Material = Enum.Material.Grass })
	end

	Kit.wallRow(ctx, 22, 8, function(cf, rng, i)
		if i % 2 == 0 then
			S.cloud(ctx, cf * CFrame.new(0, rng:NextNumber(4, 10), 0), rng:NextNumber(1.2, 1.8))
		else
			S.roundTree(ctx, cf, rng:NextNumber(1.2, 1.6), leaves[i % #leaves + 1], hx("#8B6A4A"))
		end
	end)
	Kit.clusters(ctx, 6, 3, 5, 13, function(cf, rng, i)
		if i % 2 == 0 then
			S.rocks(ctx, cf, rng:NextNumber(0.8, 1.2), rock)
		else
			S.bush(ctx, cf, rng:NextNumber(1, 1.3), leaves[2], hx("#FFFFFF"))
		end
	end)
	Kit.coreScatter(ctx, 50, function(cf, rng, i)
		if i % 2 == 0 then
			S.flower(ctx, cf, rng:NextNumber(0.8, 1.2), if i % 4 == 0 then hx("#8EC9FF") else hx("#FFFFFF"))
		else
			S.tuft(ctx, cf, rng:NextNumber(0.9, 1.3), hx("#7CD65A"))
		end
	end)
	-- Islands drifting high over the open floor, well above jump height.
	for i = 1, 6 do
		S.floatingIsland(ctx, Kit.at(ctx, ctx.rng:NextNumber(-120, 120), -120 + i * 40) * CFrame.new(0, ctx.rng:NextNumber(45, 70), 0),
			ctx.rng:NextNumber(12, 22), grass, rock, if i % 2 == 0 then leaves[1] else nil)
	end
	Kit.outside(ctx, 14, function(cf, rng)
		S.cloud(ctx, cf * CFrame.new(0, rng:NextNumber(10, 40), 0), rng:NextNumber(2, 3.5))
	end)
end
