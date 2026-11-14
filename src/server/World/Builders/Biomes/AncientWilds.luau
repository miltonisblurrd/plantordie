--!strict
-- Ancient Wilds: an overgrown ruin field. A broken temple facade with a giant statue, colonnades of
-- standing and fallen pillars, moss-covered blocks and jungle growing through the stone.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local stone = hx("#C9B994")
	local moss = hx("#6A994E")
	local leaves = { hx("#4E7A3A"), hx("#6A994E"), hx("#3E6B30") }
	local bark = hx("#5C4033")
	Kit.ground(ctx, hx("#7F8F5E"), Enum.Material.Grass)
	Kit.mood(ctx, { haze = hx("#D8E0B0"), decay = hx("#8A7A50"), density = 0.33, tint = hx("#FFF8E6"), saturation = 0.08, contrast = 0.08 })
	Kit.patches(ctx, 18, 8, 18, { hx("#8F9779"), hx("#6E8450"), hx("#9AA27E") }, Enum.Material.Grass)
	-- Old paved road down the middle, broken into slabs.
	Kit.decor(ctx, function()
		for z = -ctx.length / 2 + 14, ctx.length / 2 - 14, 16 do
			if ctx.rng:NextNumber() < 0.75 then
				Kit.part(ctx, "Paving", Vector3.new(ctx.rng:NextNumber(18, 30), 0.2, 12), Kit.at(ctx, ctx.rng:NextNumber(-6, 6), z, ctx.rng:NextNumber(-0.1, 0.1))
					* CFrame.new(0, Kit.FLOOR_TOP + 0.04, 0), stone:Lerp(Color3.new(0, 0, 0), ctx.rng:NextNumber(0, 0.2)),
					{ Material = Enum.Material.Limestone, Parent = ctx.model })
			end
		end
	end)

	-- Temple facade and statue, back left.
	local temple = Kit.landmark(ctx, -1, 0.45, 32)
	Kit.part(ctx, "Steps", Vector3.new(40, 3, 24), temple * CFrame.new(0, 1.5, 0), stone:Lerp(Color3.new(0, 0, 0), 0.1), { Material = Enum.Material.Limestone })
	Kit.part(ctx, "Steps2", Vector3.new(32, 3, 18), temple * CFrame.new(0, 4.5, 2), stone, { Material = Enum.Material.Limestone })
	for i = -2, 2 do
		S.pillar(ctx, temple * CFrame.new(i * 7, 6, -6), 1.1, stone, i == 1)
	end
	Kit.part(ctx, "Lintel", Vector3.new(26, 4, 6), temple * CFrame.new(-3, 28, -6) * CFrame.Angles(0, 0, 0.06), stone, { Material = Enum.Material.Limestone })
	S.statue(ctx, temple * CFrame.new(0, 6, 6), 1.8, hx("#A8A08A"), moss)
	-- Fallen colossus head, front right.
	local head = Kit.landmark(ctx, 1, -0.35, 18)
	Kit.part(ctx, "ColossusHead", Vector3.new(16, 18, 16), head * CFrame.new(0, 7, 0) * CFrame.Angles(0.3, 0.5, 0.25), hx("#A8A08A"), { Material = Enum.Material.Limestone })
	Kit.part(ctx, "HeadMoss", Vector3.new(17, 3, 17), head * CFrame.new(0, 15, 0) * CFrame.Angles(0.3, 0.5, 0.25), moss, { Material = Enum.Material.Grass, Decor = true })

	Kit.wallRow(ctx, 18, 7, function(cf, rng, i)
		if i % 3 == 0 then
			S.pillar(ctx, cf, rng:NextNumber(0.9, 1.2), stone, rng:NextNumber() < 0.5)
		else
			S.umbrellaTree(ctx, cf, rng:NextNumber(1.1, 1.5), leaves[i % #leaves + 1], bark)
		end
	end)
	Kit.clusters(ctx, 8, 3, 5, 13, function(cf, rng, i)
		if i % 3 == 0 then
			S.pillar(ctx, cf, rng:NextNumber(0.8, 1), stone, true)
		elseif i % 3 == 1 then
			S.rocks(ctx, cf, rng:NextNumber(0.9, 1.3), stone, Enum.Material.Limestone)
		else
			S.bush(ctx, cf, rng:NextNumber(1, 1.4), leaves[i % #leaves + 1])
		end
	end)
	Kit.coreScatter(ctx, 50, function(cf, rng, i)
		if i % 2 == 0 then
			S.pebbles(ctx, cf, rng:NextNumber(1, 1.5), stone)
		else
			S.tuft(ctx, cf, rng:NextNumber(1, 1.4), moss)
		end
	end)
	Kit.outside(ctx, 12, function(cf, rng, i)
		if i % 3 == 0 then
			S.pillar(ctx, cf, rng:NextNumber(2, 2.6), stone)
		else
			S.umbrellaTree(ctx, cf, rng:NextNumber(1.8, 2.4), leaves[i % #leaves + 1], bark)
		end
	end)
end
