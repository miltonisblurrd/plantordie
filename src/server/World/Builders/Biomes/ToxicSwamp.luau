--!strict
-- Toxic Swamp: murky mud ground, glowing toxic pools, drooping willows and dead trees, poison
-- mushrooms, a rusted barrel dump and a sickly green haze.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local toxic = hx("#A6FF00")
	local murk = hx("#3A4A22")
	local leaves = { hx("#4B5D2A"), hx("#5E7030"), hx("#394A20") }
	local bark = hx("#2F2A1E")
	Kit.ground(ctx, hx("#4B5D2A"), Enum.Material.Mud)
	Kit.mood(ctx, { haze = hx("#9FBF4A"), decay = hx("#2F3B1C"), density = 0.42, tint = hx("#EEFFD8"), saturation = 0.05, contrast = 0.1 })
	Kit.patches(ctx, 26, 8, 20, { hx("#3F4F24"), hx("#55682F"), hx("#2F3B1C") }, Enum.Material.Mud)

	-- Big toxic lake with a dead tree, back right; barrel dump, front left.
	local lake = Kit.landmark(ctx, 1, 0.45, 32)
	S.pond(ctx, lake, 28, toxic, murk, true)
	S.deadTree(ctx, lake * CFrame.new(-6, 0, 4), 2, bark)
	local dump = Kit.landmark(ctx, -1, -0.35, 16)
	for i = 0, 5 do
		local a = i * 1.1
		Kit.part(ctx, "Barrel", Vector3.new(5, 3.4, 3.4), dump * CFrame.new(math.cos(a) * 7, 2.5, math.sin(a) * 7) * Kit.UPRIGHT
			* CFrame.Angles(if i % 3 == 0 then 1.4 else 0, 0, 0), hx("#6A6A3A"), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.CorrodedMetal })
	end
	S.pond(ctx, dump * CFrame.new(0, 0, 0), 6, toxic, murk, true)

	Kit.wallRow(ctx, 18, 7, function(cf, rng, i)
		if i % 3 == 0 then
			S.deadTree(ctx, cf, rng:NextNumber(1.3, 1.8), bark)
		else
			S.willow(ctx, cf, rng:NextNumber(1.1, 1.5), leaves[i % #leaves + 1], bark)
		end
	end)
	Kit.clusters(ctx, 7, 3, 5, 13, function(cf, rng, i)
		if i % 4 == 0 then
			S.pond(ctx, cf, rng:NextNumber(4, 6), toxic, murk, true)
		elseif i % 4 == 1 then
			S.log(ctx, cf, rng:NextNumber(1, 1.3), bark, hx("#6B8E23"))
		else
			S.mushroom(ctx, cf, rng:NextNumber(0.9, 1.4), hx("#8E44AD"), hx("#C8D8A0"))
		end
	end)
	Kit.coreScatter(ctx, 50, function(cf, rng, i)
		if i % 3 == 0 then
			S.mushroomPatch(ctx, cf, rng:NextNumber(0.8, 1.1), hx("#8E44AD"), hx("#C8D8A0"))
		elseif i % 3 == 1 then
			S.crack(ctx, cf, rng:NextNumber(0.6, 1), toxic)
		else
			S.tuft(ctx, cf, rng:NextNumber(1, 1.5), hx("#5E7030"))
		end
	end)
	Kit.outside(ctx, 12, function(cf, rng, i)
		if i % 2 == 0 then
			S.willow(ctx, cf, rng:NextNumber(2, 2.6), leaves[1], bark)
		else
			S.deadTree(ctx, cf, rng:NextNumber(2.2, 3), bark)
		end
	end)
end
