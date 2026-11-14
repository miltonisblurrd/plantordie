--!strict
-- Frostbite Garden: snowfields, snow-capped pines, ice spikes, a frozen pond and a snow fort tower.
local World = script.Parent.Parent.Parent
local Kit = require(World.BiomeKit)
local S = require(World.Scenery)
local hx = Color3.fromHex

return function(ctx: Kit.Ctx)
	local snow = hx("#F5FAFF")
	local ice = hx("#9ED8FF")
	local pine = { hx("#2F6B5A"), hx("#3A7D6B"), hx("#24584B") }
	Kit.ground(ctx, hx("#E6F4FF"), Enum.Material.Snow)
	Kit.mood(ctx, { haze = hx("#DDF1FF"), decay = hx("#8CB8E6"), density = 0.42, tint = hx("#E8F4FF"), saturation = -0.05, contrast = 0.06 })
	Kit.patches(ctx, 22, 8, 22, { hx("#D6ECFF"), hx("#F0F8FF"), hx("#C9E2F7") }, Enum.Material.Snow)
	Kit.patches(ctx, 7, 6, 12, { hx("#BFE6FF") }, Enum.Material.Ice)

	local pond = Kit.landmark(ctx, 1, 0.45, 26)
	S.pond(ctx, pond, 22, hx("#BDE8FF"), hx("#A8C8E0"))
	-- Ice tower: stacked turned blocks with a glowing crown.
	local tower = Kit.landmark(ctx, -1, -0.3, 18)
	for i = 0, 4 do
		Kit.part(ctx, "IceTier", Vector3.new(16 - i * 2.5, 8, 16 - i * 2.5), tower * CFrame.new(0, 4 + i * 8, 0) * CFrame.Angles(0, i * 0.4, 0),
			ice:Lerp(snow, i * 0.12), { Material = Enum.Material.Ice })
	end
	local crown = Kit.part(ctx, "IceCrown", Vector3.new(5, 5, 5), tower * CFrame.new(0, 44, 0) * CFrame.Angles(0.6, 0.6, 0), hx("#7FD3FF"),
		{ Material = Enum.Material.Neon, Decor = true })
	Kit.light(ctx, crown, hx("#7FD3FF"), 30, 1.5)

	Kit.wallRow(ctx, 17, 7, function(cf, rng, i)
		if i % 4 == 0 then
			S.iceSpike(ctx, cf, rng:NextNumber(1.2, 1.8), ice)
		else
			S.pine(ctx, cf, rng:NextNumber(1.2, 1.8), pine[i % #pine + 1], hx("#5A4030"), snow)
		end
	end)
	Kit.clusters(ctx, 7, 3, 5, 13, function(cf, rng, i)
		if i % 3 == 0 then
			S.iceSpike(ctx, cf, rng:NextNumber(0.7, 1.1), ice)
		elseif i % 3 == 1 then
			S.rocks(ctx, cf, rng:NextNumber(0.8, 1.2), hx("#A8C0D6"), Enum.Material.Glacier)
		else
			S.bush(ctx, cf, rng:NextNumber(0.9, 1.2), hx("#DCEFFF"), hx("#B9A8FF"))
		end
	end)
	Kit.coreScatter(ctx, 50, function(cf, rng, i)
		if i % 2 == 0 then
			S.pebbles(ctx, cf, rng:NextNumber(0.8, 1.3), hx("#C7DDF0"))
		else
			S.tuft(ctx, cf, rng:NextNumber(0.8, 1.2), hx("#B9DDF2"))
		end
	end)
	Kit.outside(ctx, 14, function(cf, rng, i)
		S.pine(ctx, cf, rng:NextNumber(2.2, 3), pine[i % #pine + 1], hx("#5A4030"), snow)
	end)
end
