#!/usr/bin/env lua5.1

local floor = math.floor
local abs = math.abs

function round(x)
	return floor(x + 0.5)
end

local t = 1.515151515151515151515151

local fmt_s = "%012.8f"
local fmt = function(v)
	return fmt_s:format(v)
end

local smallest_delta = math.huge
local winner = nil

for i = 1, 50, 1 do
	local v = t * i
	local rnd = round(v)
	local delta = abs(v - rnd)

	if (delta < smallest_delta) then
		smallest_delta = delta
		winner = { rnd, i }
	end

	print(i, fmt(v), fmt(rnd), fmt(delta))
end

print("# winner: " .. winner[1] .. " / " .. winner[2])

