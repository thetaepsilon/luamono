dofile("bignat.lua")

--#pragma region utility
local function expect(num, bytes)
	local nl = num.length
	assert(num.at(nl + 1) == nil)

	for i = 1, nl, 1 do
		local p = num.at(i)
		assert(p ~= nil)
		assert(p >= 0)
		assert(p < 256)
	end

	local expected_len = #bytes
	assert(nl == expected_len)

	for idx = 1, expected_len, 1 do
		local v = bytes[idx]
		local actual = num.at(idx)
		if actual ~= v then
			error("idx " .. idx .. " expected " .. v .. " got " .. actual)
		end
	end
end
--#pragma endregion

--#pragma region common
local zero = bignat(0)
expect(zero, {})
local one = bignat(1)
expect(one, {1})
local two = bignat(2)
expect(two, {2})

local position_max = bignat(255)
expect(position_max, {255})
local power_1 = bignat(256)
expect(power_1, {0, 1})
--#pragma endregion



--#pragma region addition
do
	local r1 = zero + zero
	expect(r1, {})

	local r2 = zero + one
	expect(r2, {1})

	local r3 = one + zero
	expect(r3, {1})

	local r4 = one + one
	expect(r4, {2})

	local r5 = power_1 + power_1
	expect(r5, {0, 2})

	local r6 = position_max + one
	expect(r6, {0, 1})

	local r7 = position_max + two
	expect(r7, {1, 1})

	local r8 = power_1 + one
	expect(r8, {1, 1})
end
--#pragma endregion




--[[
local r1 = bignat(0) - bignat(0)
assert(r1.length == 0)

assert(zero.try_sub(bignat(1)) == nil)



assert(one.try_sub(two) == nil)
assert(one.try_sub(bignat(258)) == nil)
--assert(one.try_sub(bignat(257)) == nil)
--assert(one.try_sub(bignat(256)) == nil)

local r2 = one - zero
assert(r2.length == 1)
assert(r2.at(1) == 1)

local r3 = two - one
assert(r3.length == 1)
assert(r3.at(1) == 1)



local r4 = power_1 - one
assert(r4.length == 1)
assert(r4.at(1) == 255)
]]

