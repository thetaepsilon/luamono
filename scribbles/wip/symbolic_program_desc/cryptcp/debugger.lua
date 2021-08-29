-- factory of objects that log calls to themselves via metatables,
-- and return more of themselves in turn.
-- objects from different factory instances will never have knowledge of each other.

-- it accepts a factory for callback functions,
-- the latter of which will be instantiated upon object creation with the object and it's label,
-- and will be called whenever an object method or function would be invoked.

local setmeta = setmetatable

local function create_factory(callback_factory)
	assert(type(callback_factory) == "function")

	local objects = {}
	-- XXX: could experiment with weak keys here,
	-- but those are not actually guaranteed to be gone immediately even after GC
	-- (depending on lua version).

	local _register = function(obj, label)
		assert(objects[obj] == nil)
		objects[obj] = label
		return obj
	end

	-- accessor setup.
	-- these are created one time upon each field access,
	-- and detonate if called more than once;
	-- this is intended to catch attempts at hanging onto methods of symbolic objects.
	!?

	-- internal object creation.
	local _create_object = function(label)
		local self = {}
		local meta = {
			__newindex = function(k, v)
				error(
					"modification attempt on object " ..
					label .. ": " .. tostring(k) .. " = " ..
					tostring(v)
				)
			end,
			__index = function(k)
				
			end,
			__metatable = false,
		}

		return _register(self, label)
	end

	local _root_index = 0



	-- get the name associated with a given root object.
	-- if the provided object is not from this factory, returns nil.
	-- (this is not a part of the created objects,
	-- so that no method/function names are reserved by this mechanism.
	-- furthermore these objects should only be known to the caller.)
	local get_label = function(obj)
		return objects[obj]
	end

end
