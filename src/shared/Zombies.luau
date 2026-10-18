--!strict
-- Lane zombies (P4). Boss every Config-defined night.
export type Zombie = { Id: string, Name: string, Hp: number, Speed: number, Damage: number, Color: Color3 }

return {
	BossEveryNights = 5,
	MaxPerPlot = 20,
	List = {
		{ Id = "Walker", Name = "Walker", Hp = 20, Speed = 2, Damage = 5, Color = Color3.fromRGB(110, 160, 90) },
		{ Id = "Runner", Name = "Runner", Hp = 12, Speed = 4, Damage = 4, Color = Color3.fromRGB(200, 120, 60) },
	} :: { Zombie },
}
