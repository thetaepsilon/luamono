#!/usr/bin/env lua5.3
--[[
an especially primitive more(1) thing that I use to help me read the code of others.
it prints exactly one source line at a time, waiting for the enter key between each.
it doesn't attempt to be clever with line wrapping in any shape or form
(this is 2021, I think my terminal can handle the odd long line).
]]



assert(select("#", ...) == 1, [[

Usage: more.lua filename

]])

local filename = ...
local file = assert(io.open(filename))

-- the fact :lines() returns a self-contained iterator function is technically undocumented,
-- but it's helpful to be able to call this without tracking the hidden state vars in for-loops.
local line = file:lines()

local out = io.stdout
for _ in io.stdin:lines() do
	-- note that in the usual terminal echo mode,
	-- the preceding enter press will show on the terminal.
	-- just using print() would cause double newlines.
	out:write(line())
	out:flush()
end

