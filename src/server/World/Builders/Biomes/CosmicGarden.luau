--!strict
-- Cosmic Garden: violet starfield ground with nebula seams, glowing star plants, floating planets
-- and asteroids overhead, a star-gate arch and deep purple-blue light.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local pink = hx("#FFD6FF")
	local cyan = hx("#4CC9F0")
	local violet = hx("#7209B7")
	local stems = hx("#3A1A6A")
	Kit.ground(ctx, hx("#1B1035"), Enum.Material.Slate)
	Kit.mood(ctx, { haze = hx("#5A3FA0"), decay = hx("#120A2A"), density = 0.45, tint = hx("#E8DEFF"), saturation = 0.25, contrast = 0.14, brightness = -0.04 })
	Kit.patches(ctx, 22, 8, 20, { hx("#24164A"), hx("#160C2C"), hx("#2E1A5A") }, Enum.Material.Slate)
	Kit.coreScatter(ctx, 30, function(cf, rng, i)
		S.crack(ctx, cf, rng:NextNumber(0.8, 1.4), if i % 2 == 0 then cyan else hx("#B47CFF"))
	end)

	-- Star gate: ring arch with a glowing core, back right.
	local gate = Kit.landmark(ctx, 1, 0.45, 24)
	Kit.part(ctx, "GateRing", Vector3.new(4, 34, 34), gate * CFrame.new(0, 19, 0), hx("#2A1A50"), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate })
	local core = Kit.part(ctx, "GateCore", Vector3.new(4.4, 26, 26), gate * CFrame.new(0, 19, 0), cyan,
		{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Transparency = 0.35, Decor = true })
	Kit.light(ctx, core, cyan, 40, 1.6)
	-- Planets hang over the left band.
	local orbit = Kit.landmark(ctx, -1, -0.3, 20)
	S.planet(ctx, orbit * CFrame.new(0, 48, 0), 14, hx("#B47CFF"), pink)
	S.planet(ctx, orbit * CFrame.new(-10, 30, 40), 6, hx("#4CC9F0"))
	S.giantFlower(ctx, orbit, 1.4, violet, cyan, stems, true)

	Kit.wallRow(ctx, 17, 7, function(cf, rng, i)
		if i % 3 == 0 then
			S.crystals(ctx, cf, rng:NextNumber(1.2, 1.7), if i % 2 == 0 then hx("#B47CFF") else cyan)
		else
			S.giantFlower(ctx, cf, rng:NextNumber(0.8, 1.1), if i % 2 == 0 then violet else hx("#3A0CA3"), if i % 2 == 0 then pink else cyan, stems)
		end
	end)
	Kit.clusters(ctx, 7, 3, 5, 12, function(cf, rng, i)
		if i % 2 == 0 then
			S.rocks(ctx, cf, rng:NextNumber(0.8, 1.2), hx("#2E2450"))
		else
			S.mushroom(ctx, cf, rng:NextNumber(0.8, 1.2), if i % 4 == 1 then cyan else pink, hx("#4A2A7A"))
		end
	end)
	Kit.coreScatter(ctx, 30, function(cf, rng, i)
		S.flower(ctx, cf, rng:NextNumber(0.8, 1.2), if i % 2 == 0 then pink else cyan)
	end)
	for i = 1, 16 do
		local x = ctx.rng:NextNumber(-170, 170)
		local z = ctx.rng:NextNumber(-140, 140)
		if i % 4 == 0 then
			S.planet(ctx, Kit.at(ctx, x, z) * CFrame.new(0, ctx.rng:NextNumber(50, 75), 0), ctx.rng:NextNumber(3, 6), hx("#5A4A8A"))
		else
			S.orb(ctx, Kit.at(ctx, x, z) * CFrame.new(0, ctx.rng:NextNumber(20, 60), 0), ctx.rng:NextNumber(0.4, 0.8), Color3.new(1, 1, 1))
		end
	end
	Kit.outside(ctx, 10, function(cf, rng, i)
		S.planet(ctx, cf * CFrame.new(0, rng:NextNumber(40, 80), 0), rng:NextNumber(6, 14), if i % 2 == 0 then hx("#7B2CBF") else hx("#2A6FDB"),
			if i % 3 == 0 then pink else nil)
	end)
end
