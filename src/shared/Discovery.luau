--!strict
-- Discoveries. `collection` ("species|variant" -> true) is permanent: every server grant path
-- calls `record`, entries are never removed, and the index and its rewards read only it.
-- `of` derives the set from current holdings; `fold` merges that into `collection` for records
-- saved before every path recorded.

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

function Discovery.record(p: { collection: { [string]: boolean } }, species: string, variant: string?)
	p.collection[species .. "|" .. (variant or "Normal")] = true
end

-- Tolerates missing or malformed maps (raw pre-reconcile records).
function Discovery.fold(d: { [string]: any })
	if type(d.collection) ~= "table" then
		d.collection = {}
	end
	local function tbl(v: any): { [any]: any }
		return if type(v) == "table" then v else {}
	end
	local held: { [string]: any } = { collection = {}, seeds = {}, expedition = {}, plants = {}, planted = {} }
	for _, field in { "seeds", "expedition" } do
		for k, n in tbl(d[field]) do
			if type(k) == "string" and type(n) == "number" then
				held[field][k] = n
			end
		end
	end
	for _, field in { "plants", "planted" } do
		for k, item in tbl(d[field]) do
			if type(item) == "table" and type(item.species) == "string" then
				held[field][k] = { species = item.species, variant = if type(item.variant) == "string" then item.variant else "Normal" }
			end
		end
	end
	for k in Discovery.of(held :: any) do
		d.collection[k] = true
	end
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
