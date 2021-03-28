#!/usr/bin/env lua5.1

local usage = [[

# Usage: set_insersection_and_uniques fileA fileB unique_to_A_path unique_to_B_path both_path
#	reads fileA and fileB as sets, one item per line. lines do not have to be unique nor sorted.
#	items unique to set A will be written to unique_to_A_path and vice versa.

]]

if select("#", ...) ~= 5 then
	error(usage)
end

local open = io.open
local ro = function(path)
	return assert(open(path, "r"))
end
local rw = function(path)
	return assert(open(path, "w+"))
end

local read_set_consume = function(handle)
	local set = {}
	for i in handle:lines() do
		set[i] = true
	end
	handle:close()
	return set
end

local finish = function(handle)
	handle:flush()
	handle:close()
end



local _path_in_a, _path_in_b, _path_out_unique_a, _path_out_unique_b, _path_out_common = ...

local in_a	= ro(_path_in_a)
local in_b	= ro(_path_in_b)

local out_unique_a	= rw(_path_out_unique_a)
local out_unique_b	= rw(_path_out_unique_b)
local out_common	= rw(_path_out_common)



local set_a = read_set_consume(in_a)
local set_b = read_set_consume(in_b)



for element, _ in pairs(set_a) do
	local l = element .. "\n"
	if set_b[element] then
		set_b[element] = nil
		out_common:write(l)
	else
		out_unique_a:write(l)
	end
end
finish(out_common)
finish(out_unique_a)


-- anything that was in A will have been removed from B so only B's unique elements remain.
for element, _ in pairs(set_b) do
	out_unique_b:write(element .. "\n")
end
finish(out_unique_b)



