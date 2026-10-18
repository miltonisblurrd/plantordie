--!strict
export type Rarity = {
	Id: string,
	Name: string,
	Order: number,
	Multiplier: number,
	Color: Color3,
	StrokeColor: Color3?,
}

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local list: { Rarity } = {
	{ Id = "Common", Name = "Common", Order = 1, Multiplier = 1, Color = hex("#B0B0B0") },
	{ Id = "Uncommon", Name = "Uncommon", Order = 2, Multiplier = 1.5, Color = hex("#4CD964") },
	{ Id = "Rare", Name = "Rare", Order = 3, Multiplier = 2.5, Color = hex("#3A8DFF") },
	{ Id = "Epic", Name = "Epic", Order = 4, Multiplier = 4, Color = hex("#A64DFF") },
	{ Id = "Legendary", Name = "Legendary", Order = 5, Multiplier = 7, Color = hex("#FFB020") },
	{ Id = "Mythical", Name = "Mythical", Order = 6, Multiplier = 12, Color = hex("#FF4D6D") },
	{ Id = "Divine", Name = "Divine", Order = 7, Multiplier = 25, Color = hex("#FFFFFF"), StrokeColor = hex("#FFB020") },
}

local byId: { [string]: Rarity } = {}
for _, r in list do
	byId[r.Id] = r
end

return {
	List = list,
	ById = byId,
}
