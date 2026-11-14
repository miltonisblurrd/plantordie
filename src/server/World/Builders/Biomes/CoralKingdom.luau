--!strict
-- Coral Kingdom: a sea-floor garden of branching and fan corals, kelp, a giant clam shell, a
-- sunken coral arch, drifting bubbles and deep blue light.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local corals = { hx("#FF7F50"), hx("#FF5E8A"), hx("#FFD166"), hx("#B07CFF"), hx("#4CE0C0") }
	local kelp = hx("#2E9E6A")
	Kit.ground(ctx, hx("#E7D8B0"), Enum.Material.Sand)
	Kit.mood(ctx, { haze = hx("#5FB8FF"), decay = hx("#1A4F9A"), density = 0.42, tint = hx("#D8ECFF"), saturation = 0.2, contrast = 0.06 })
	Kit.patches(ctx, 24, 8, 20, { hx("#D9C79C"), hx("#F0E2BE"), hx("#9FC9D9") }, Enum.Material.Sand)
	Kit.patches(ctx, 6, 5, 9, { hx("#3A8FB0") }, Enum.Material.Pebble)

	S.shell(ctx, Kit.landmark(ctx, -1, -0.35, 20), 3.2, hx("#FFD1DC"))
	local arch = Kit.landmark(ctx, 1, 0.45, 26)
	S.arch(ctx, arch, 1.5, hx("#FF7F50"), Enum.Material.Pebble)
	for i = 0, 3 do
		S.coral(ctx, arch * CFrame.new(-14 + i * 9, 0, 8), 1.4, corals[i % #corals + 1])
	end

	Kit.wallRow(ctx, 15, 6, function(cf, rng, i)
		if i % 3 == 0 then
			S.kelp(ctx, cf, rng:NextNumber(1.6, 2.4), kelp)
		elseif i % 3 == 1 then
			S.fanCoral(ctx, cf, rng:NextNumber(1.2, 1.7), corals[i % #corals + 1])
		else
			S.coral(ctx, cf, rng:NextNumber(1.4, 2), corals[i % #corals + 1])
		end
	end)
	Kit.clusters(ctx, 8, 3, 5, 12, function(cf, rng, i)
		if i % 4 == 0 then
			S.rocks(ctx, cf, rng:NextNumber(0.8, 1.2), hx("#5A7FA0"), Enum.Material.Pebble)
		elseif i % 4 == 1 then
			S.shell(ctx, cf, rng:NextNumber(0.6, 0.9), hx("#FFE3EC"))
		else
			S.coral(ctx, cf, rng:NextNumber(0.9, 1.3), corals[i % #corals + 1])
		end
	end)
	Kit.coreScatter(ctx, 50, function(cf, rng, i)
		if i % 2 == 0 then
			S.pebbles(ctx, cf, rng:NextNumber(0.8, 1.2), hx("#C8B48A"))
		else
			S.kelp(ctx, cf, rng:NextNumber(0.35, 0.5), kelp)
		end
	end)
	for _ = 1, 14 do
		S.orb(ctx, Kit.at(ctx, ctx.rng:NextNumber(-160, 160), ctx.rng:NextNumber(-140, 140)) * CFrame.new(0, ctx.rng:NextNumber(5, 30), 0),
			ctx.rng:NextNumber(0.4, 0.9), hx("#D8F3FF"))
	end
	Kit.outside(ctx, 12, function(cf, rng, i)
		S.coral(ctx, cf, rng:NextNumber(3, 4), corals[i % #corals + 1])
	end)
end
