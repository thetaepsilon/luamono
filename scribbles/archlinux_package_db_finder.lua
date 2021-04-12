#!/usr/bin/env lua5.3

local _usage = [[

Usage: archlinux_package_db_finder name_of_package fieldname < core.db.after_gunzip

]]


local _getline = io.stdin:lines()
local _lineno = 0
local getline = function()
	local line = _getline()
	if line ~= nil then
		_lineno = _lineno + 1
	end
	return line
end
local lineno = function()
	return "line " .. tostring(_lineno)
end




local function find_plain(str)
	local start = lineno()

	for line in getline do
		if line == str then
			return
		end
	end
	error(
		"string \"" .. str .. "\" not found after " .. start ..
			" (incorrect input format?)"
	)
end

local function find_pattern(pat)
	local start = lineno()

	for line in getline do
		-- varargs handling is hard... thankfully we only really need one
		local match = line:match(pat)
		if match then
			return line, match
		end
	end
	error(
		"no line matching " .. pat .. " after " .. start ..
			" (incorrect input format?)"
	)
end





local function find_field(fieldname)
	local start = lineno()
	while true do
		local line, match = find_pattern("^%%([A-Z]*)%%$")
		if match == fieldname then
			-- ... then the next line should be the value of interest,
			-- but just check we didn't hit EOF first.
			local v = assert(getline(), "end of file reached while reading field value")
			return v
		end
	end
	-- if evidence was even needed I was shotgun parsing this...
	error("unreachable!?")
end

local function find_package_field(packagename, fieldname)
	while true do
		find_plain("%NAME%")
		local name = getline()
		if name == packagename then
			return find_field(fieldname)
		end
	end
	error("package " .. packagename .. " not found")
end



assert(select("#", ...) == 2, _usage)
local packagename, fieldname = ...
local v = find_package_field(packagename, fieldname)
print(v)

