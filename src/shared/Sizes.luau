--!strict
export type Size = {
	Id: string,
	Order: number,
	Multiplier: number,
	Weight: number,
	VisualScale: number, -- Giant capped at 1.8x tile (brand.md)
}

local list: { Size } = {
	{ Id = "Small", Order = 1, Multiplier = 1, Weight = 60, VisualScale = 0.8 },
	{ Id = "Medium", Order = 2, Multiplier = 2, Weight = 25, VisualScale = 1.0 },
	{ Id = "Large", Order = 3, Multiplier = 5, Weight = 10, VisualScale = 1.25 },
	{ Id = "Huge", Order = 4, Multiplier = 10, Weight = 4, VisualScale = 1.5 },
	{ Id = "Giant", Order = 5, Multiplier = 25, Weight = 1, VisualScale = 1.8 },
}

local byId: { [string]: Size } = {}
for _, s in list do
	byId[s.Id] = s
end

return {
	List = list,
	ById = byId,
}
