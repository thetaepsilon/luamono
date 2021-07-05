local percent_decode = function(s)
	local r = s:gsub("%%(..)", function(s2)
		local value = assert(tonumber(s2, 16), "bad percent encoded hex")
		return string.char(value)
	end)
	return r
end


local split = function(s)
	local ret = {}
	local index = 0
	s:gsub("[^&]*", function(m)
		index = index + 1
		ret[index] = m
		return false
	end)
	return ret
end

local debug = function(v)
	print("#", type(v), v)
end
local debug_ret = function(enable, ...)
	if enable then
		print("#", select("#", ...), ...)
	end
	return ...
end



local input = ...
assert(input, "where's my string?")

local outer_pat = "^[^?]*%?([^?]*)(%??.*)$"
local params, garbage = input:match(outer_pat)
assert(params, "doesn't look like a param'd URL (no first ? for params)")
assert(#garbage == 0, "more than one ? in URL, wtf")


params = split(params)
--[[
for i, s in ipairs(params) do
	print(s)
end
print()
]]

for i, s in ipairs(params) do
	--debug(s)
	--debug_ret(true, s:match("^([^=]*)(.*)$"))
	local k, eq, v, garbage = debug_ret(false, s:match("^([^=]*)(=)([^=]*)(=?.*)$"))
	if not eq then
		error("param at index " .. i .. " isn't (no = char)")
	end
	if not k then
		error("missing key in param " .. i)
	end
	print(k)

	assert(#garbage == 0, "multiple = chars in parameter invalid")

	local pv = percent_decode(v)
	print(pv)
	print()
end

