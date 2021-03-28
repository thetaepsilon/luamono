--[[
yet another lua bigint (well, big natural numbers actually) library,
but this one always operates as a variable-length "byte" array
(e.g. internally it is essentially base-256).
this allows for more convenient serialisation into binary forms.
(e.g. to serialise to uint64, check the value is in bounds,
then pick out the values, transform with string.char, and combine in desired byte order.)
]]

-- oh vey, old JS style closure "modules" going on here to allow #include based builds...
(function()	
	-- "imports"
	local modf = math.modf
	local bytecast = string.char
	local mod = math.fmod
	local assert = assert
	local error = error
	local setmeta = setmetatable





	-- "static member" functions
	-- note: add_inner expects to be called with zero for starting index.
	local function add_inner(ba, bb, out, idx, carry)
		local nidx = idx + 1

		local _va = ba[nidx]
		local _vb = bb[nidx]
		-- nothing left in either number and no carry bit?
		-- we're done, go home
		if not (_va or _vb or carry) then return idx end

		local va = _va or 0
		local vb = _vb or 0

		local intermediate = va + vb + (carry and 1 or 0)

		local this_position = mod(intermediate, 256)
		out[nidx] = this_position
		carry = (intermediate >= 256)
		idx = nidx
		return add_inner(ba, bb, out, idx, carry)
	end

	-- three-way comparison.
	-- returns 1 for a > b, 0 for a == b, -1 for a < b.
	local compare_inner = function(ba, la, bb, lb)
		-- due to the no leading zeroes invariant:
		-- if one number has more positions then it is bigger.
		if la > lb then return 1 end
		if la < lb then return -1 end

		-- if both have the same count of positions then work backwards from the highest.
		-- break as soon as either number is clearly greater.
		-- obviously for instance (in base 10 as an example)
		-- we know that 500 > 498 (5 > 4) despite the lower positions.
		for i = la, 1, -1 do
			local va = ba[i]
			local vb = bb[i]
			if va > vb then return 1 end
			if va < vb then return -1 end
		end

		-- if we got to the end and no winner, they're the same.
		return 0
	end

	-- implied ordering: a - b
	local function subtract_inner_padded(ba, bb, out, idx, borrow)
		error("ENOTIMPL")
	end
	-- subtraction can give us leading zeroes so trim them off.
	local subtract_inner = function(ba, bb, out, borrow)
		local len = subtract_inner_padded(ba, bb, out, 0, borrow)
		if not len then return nil end
		local rlen = len
		print("# trim", unpack(out, 1, len))
		for i = len, 1, -1 do
			local v = out[i]
			assert(v)
			if (v > 0) then break end
			out[i] = nil
			rlen = rlen - 1
		end
		return len
	end





	-- metatable functions - in this case operator overloads.
	local operator_add = function(a, b)
		return a.add(b)
	end
	local operator_subtract = function(a, b)
		return a.sub_or_explode(b)
	end





	-- hidden keys to stash our own member vars at in the self table.
	-- not foolproof from tampering but makes it awkward to do so at least.
	-- tables are guaranteed unique keys for this by definition.
	local key_bytes = {}
	local key_length = {}





	-- member functions and inner private constructor,
	-- called by operator functions as well
	local function members(bytes, length)
		-- sanity guard against the subtract case,
		-- where it's computation signals underflow via a nil length.
		assert(type(length) == "number")
		assert(length >= 0)
		local self = {}

		for i = 1, length, 1 do
			local v = bytes[i]
			assert(type(v) == "number")
			assert(v < 256)
			assert(v >= 0)
		end

		-- leading byte should be non-zero for non-zero nats...
		if length > 0 then
			assert(bytes[length] > 0)
		end

		-- check for the absence of any other keys in the table.
		-- this includes out of bounds bytes hiding beyond length.
		for k, _ in pairs(bytes) do
			assert(type(k) == "number")
			assert(k <= length)
			assert(k > 0)
		end

		-- "private" members using hidden keys.
		self[key_bytes] = bytes
		self[key_length] = length

		self.length = length
		self.at = function(idx)
			if idx > length then
				return nil
			else
				return assert(bytes[idx])
			end
		end

		self.compare = function(other)
			error("ENOIMPL SEC")
		end

		self.serialize = function(width, le_order)
			--assert(type(width) == "number")
			local t = type(width)
			if t ~= "number" then
				error("width: " .. t)
			end
			assert(width > 0)
			assert(mod(width, 1.0) == 0)

			if (width < length) then return nil end

			-- most significant byte first in default (big-endian) mode,
			-- but we store little-endian internally.
			-- I keep wanting to type "start" and "end" but the latter is a keyword.
			local first, last, incr = width, 1, -1
			if le_order then
				first, last, incr = 1, width, 1
			end
			local s = ""
			for i = first, last, incr do
				s = s .. bytecast(bytes[i] or 0)
			end

			return s
		end

		self.add = function(other)
			local result_bytes = {}
			local other_bytes = assert(other[key_bytes])
			local result_len = add_inner(bytes, other_bytes, result_bytes, 0, false)
			return members(result_bytes, result_len)
		end
		local try_sub = function(other)
			local result_bytes = {}
			local other_bytes = assert(other[key_bytes])
			-- underflow signalled by nil length
			local result_len = subtract_inner(bytes, other_bytes, result_bytes, false)
			print()
			if not result_len then
				return nil
			end
			return members(result_bytes, result_len)
		end
		self.try_sub = try_sub
		self.sub_or_explode = function(other)
			return assert(try_sub(other), "natural number underflow!")
		end

		setmeta(self, {
			__add = operator_add,
			__sub = operator_subtract,
		})

		return self
	end

	-- actual constructor logic here; members defined above.
	function bignat(_value)
		assert(_value >= 0, "bignats can't be negative.")
		local original_uint, fract = modf(_value)
		assert(fract == 0, "bignats can't handle fractions.")
		_value = nil
		_fract = nil

		local self = {}
		local bytes = {}
		local v = original_uint
		local length = 0
		while (v > 0) do
			length = length + 1
			local byte = mod(v, 256)
			bytes[length] = byte
			v = modf(v / 256)
		end
		-- yes, this technically means that if we're zero we hold no data!

		return members(bytes, length)
	end

end)()

