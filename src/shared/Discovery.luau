--!strict
-- What the collection index shows as discovered: the saved `collection` set plus everything the
-- player holds right now (seeds, the unbanked bag, inventory plants, planted plants). Keys are
-- "species|variant". Deriving it means older profiles and every grant path count without each
-- path having to remember to write `collection`.

local Discovery = {}

type Holder = { species: string, variant: string }
export type ProfileLike = {
	collection: { [string]: boolean },
	seeds: { [string]: number },
	expedition: { [string]: number },
	plants: { [string]: Holder },
	planted: { [string]: Holder },
}

Discovery.VariantOrder = { "Normal", "Neon", "Mega" }

function Discovery.of(d: ProfileLike): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for k, v in d.collection do
		if v then
			out[k] = true
		end
	end
	for species, n in d.seeds do
		if n > 0 then
			out[species .. "|Normal"] = true
		end
	end
	for species, n in d.expedition do
		if n > 0 then
			out[species .. "|Normal"] = true
		end
	end
	for _, list in { d.plants, d.planted } do
		for _, item in list do
			out[item.species .. "|" .. item.variant] = true
		end
	end
	return out
end

-- Highest variant discovered for a species, or nil if none.
function Discovery.best(set: { [string]: boolean }, species: string): string?
	local best = nil
	for _, v in Discovery.VariantOrder do
		if set[species .. "|" .. v] then
			best = v
		end
	end
	return best
end

return Discovery
