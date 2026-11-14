--!strict
-- Enchanted Grove: an ancient world tree with glowing roots, mossy stones, standing rune stones,
-- deep green canopy and drifting wisps.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local glow = hx("#7CFFCB")
	local magic = hx("#C77DFF")
	local leaves = { hx("#2E8B57"), hx("#1F6E4A"), hx("#3FA36B") }
	local bark = hx("#4A3A2E")
	Kit.ground(ctx, hx("#2E7D50"), Enum.Material.Grass)
	Kit.mood(ctx, { haze = hx("#9FE8C8"), decay = hx("#2A5A4A"), density = 0.4, tint = hx("#E6FFF4"), saturation = 0.18, contrast = 0.08 })
	Kit.patches(ctx, 24, 8, 18, { hx("#3A9460"), hx("#246B44"), hx("#4BAA6E") }, Enum.Material.Grass)
	Kit.patches(ctx, 8, 5, 9, { hx("#5C7A3A") }, Enum.Material.LeafyGrass)

	S.giantTree(ctx, Kit.landmark(ctx, -1, 0.35, 34), 1.5, leaves[1], bark, glow)
	-- Rune stone circle, front right.
	local circle = Kit.landmark(ctx, 1, -0.35, 26)
	for i = 0, 5 do
		local a = i * math.pi / 3
		local stone = Kit.part(ctx, "RuneStone", Vector3.new(4, 12 + (i % 2) * 4, 3), circle * CFrame.new(math.cos(a) * 18, 7, math.sin(a) * 18)
			* CFrame.Angles(0, -a, 0.05), hx("#6E7A70"), { Material = Enum.Material.Cobblestone })
		Kit.part(ctx, "Rune", Vector3.new(4.2, 2, 0.4), stone.CFrame * CFrame.new(0, 2, 0), magic, { Material = Enum.Material.Neon, Decor = true })
	end
	S.orb(ctx, circle * CFrame.new(0, 10, 0), 2.5, magic, true)

	Kit.wallRow(ctx, 20, 8, function(cf, rng, i)
		if i % 4 == 0 then
			S.giantTree(ctx, cf, rng:NextNumber(0.5, 0.65), leaves[i % #leaves + 1], bark)
		else
			S.roundTree(ctx, cf, rng:NextNumber(1.4, 1.9), leaves[i % #leaves + 1], bark)
		end
	end)
	Kit.clusters(ctx, 7, 3, 5, 13, function(cf, rng, i)
		if i % 3 == 0 then
			S.log(ctx, cf, rng:NextNumber(1, 1.3), bark, hx("#6FCF6A"))
		elseif i % 3 == 1 then
			S.boulder(ctx, cf, rng:NextNumber(0.6, 0.9), hx("#5E6B62"), Enum.Material.Cobblestone)
		else
			S.bush(ctx, cf, rng:NextNumber(1, 1.4), leaves[3], glow)
		end
	end)
	Kit.coreScatter(ctx, 60, function(cf, rng, i)
		if i % 3 == 0 then
			S.flower(ctx, cf, rng:NextNumber(0.8, 1.2), if i % 2 == 0 then magic else glow)
		else
			S.tuft(ctx, cf, rng:NextNumber(0.9, 1.4), hx("#3FA36B"))
		end
	end)
	for i = 1, 8 do
		S.orb(ctx, Kit.at(ctx, ctx.rng:NextNumber(-150, 150), ctx.rng:NextNumber(-140, 140)) * CFrame.new(0, ctx.rng:NextNumber(6, 16), 0), 0.7,
			if i % 2 == 0 then glow else magic)
	end
	Kit.outside(ctx, 12, function(cf, rng, i)
		S.roundTree(ctx, cf, rng:NextNumber(2.4, 3.2), leaves[i % #leaves + 1], bark)
	end)
end
