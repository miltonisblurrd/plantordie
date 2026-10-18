--!strict
-- Limited-time events (P5). Windows are UTC unix seconds.
export type Event = { Id: string, Name: string, StartsAt: number, EndsAt: number, Currency: string }

local Events = {
	List = {
		-- 2026-10-17 00:00 PT (07:00 UTC) through 2026-11-02 23:59:59 PT (2026-11-03 07:59:59 UTC)
		{ Id = "Halloween2026", Name = "Halloween", StartsAt = 1792220400, EndsAt = 1793692799, Currency = "Candy" },
	} :: { Event },
}

function Events.active(now: number): Event?
	for _, e in Events.List do
		if now >= e.StartsAt and now <= e.EndsAt then
			return e
		end
	end
	return nil
end

return Events
