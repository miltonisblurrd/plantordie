--!strict
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "QA", "Qi" }

local function suffixed(n: number): (string, string)
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return sign, tostring(math.floor(n))
	end
	local s = if n >= 100 then string.format("%d", math.floor(n)) else string.format("%.1f", math.floor(n * 10) / 10)
	s = s:gsub("%.0$", "")
	return sign, s .. SUFFIXES[i]
end

function Format.money(n: number): string
	local sign, s = suffixed(n)
	return sign .. "$" .. s
end

-- Same suffixes without "$": "96K", "1.2QA".
function Format.short(n: number): string
	local sign, s = suffixed(n)
	return sign .. s
end

function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Human duration: "45s", "2m 05s", "3h 00m", "2d 4h".
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return `{seconds}s`
	elseif seconds < 3600 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	elseif seconds < 86400 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%dd %dh", seconds // 86400, (seconds % 86400) // 3600)
end

return Format
