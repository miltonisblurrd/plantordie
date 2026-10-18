--!strict
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.money(n: number): string
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return sign .. "$" .. tostring(math.floor(n))
	end
	local s = if n >= 100 then string.format("%d", math.floor(n)) else string.format("%.1f", math.floor(n * 10) / 10)
	s = s:gsub("%.0$", "")
	return sign .. "$" .. s .. SUFFIXES[i]
end

function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
