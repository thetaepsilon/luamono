#!/usr/bin/env lua5.3

if select("#", ...) > 0 then
	error([[
Usage: some_other_program | list_grouper.lua
reads lines from stdin then interactively prompts the tty for a group to assign each line to.
the tool supports defining new groups on the fly.

when EOF on stdin is reached, the user is prompted for a directory to save the groups in.
this directory will be populated with one file per group, named after the group.
(appropriate sanitisation is applied to group names when defined to avoid weird filename issues.)
	]])
end

term = assert(io.open("/dev/tty"))
getline = term:lines()

local _out = io.stdout
local wr = function(str)
	_out:write(str)
	_out:flush()
end


local prompt = function(p)
	wr(p)
	local r = getline()
	if not r then
		wr("\n")
	end
	return r
end




local hex = "%02x"
local sanitise_gsub = function(c)
	-- XXX: assuming ascii codes much...
	-- then again, show me one practical OS where string.byte doesn't return ascii values.
	local v = c:byte()
	-- FIXME: rip UTF-8 and codepages.
	if v < 0x20 or v > 0x7E then
		return "\\x" .. hex:format(v)
	else
		-- the backslash itself introduces an escape sequence so escape that too...
		return (c == "\\") and "\\\\" or c
	end
end
local sanitise = function(s)
	local rep, matched = s:gsub(".", sanitise_gsub)
	-- blank line? signal to ignore it.
	-- XXX: doing so is hard-coded.
	if matched == 0 then
		return nil
	end
	return rep
end



local _legals = {
	"abcdefghijklmnopqrstuvwxyz",
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"0123456789_-."
}
local legal = {}
local function recset (t, v, ...)
	if not v then return end
	t[v] = true
	return recset(t, ...)
end
for _, v in ipairs(_legals) do
	recset(legal, v:byte(1, #v))
end

local legal_rec = function(v, ...)
	if not v then
		return true
	end
	if not legal[v] then
		return false
	end
	return legal_rec(...)
end
local is_legal_groupname = function(name)
	return legal_rec(name:byte(1, #name))
end







----#### prompt loop handling logic ####----

local retcheck = function(c, t)
	assert(type(c) == "function", "initial or returned callback was not a function.")
	assert(type(t) == "string", "initial or next prompt text was not a string.")
end
local prompt_loop = function(callback, prompt_text, cancel)
	retcheck(callback, prompt_text)

	while true do
		response = prompt(prompt_text)
		next_callback, next_prompt = callback(response, print)

		-- cancel is passed in as an object
		-- (assumed to be distinct from callback functions)
		-- so that callers can decide on policy;
		-- should any callback be able to abort the loop (uncatchable panic style),
		-- or just the top-level one (strict control flow style)?
		-- it is assumed that if the latter is desired,
		-- only the initial callback will have a handle to the cancel object.
		if next_callback == cancel then return end

		-- if the callback returned nil,
		-- that's interpreted to mean "don't advance, stay on the current prompt".
		-- otherwise both the next callback and the next prompt must be returned.
		if next_callback then
			retcheck(next_callback, next_prompt)
			callback = next_callback
			prompt_text = next_prompt
		end
	end
end







local reserved = {
	["#"] = "newgroup",
	["_"] = "ignore"
}

-- TODO: I spy a useful utility function to be factored out!
local match = function(data, matches)
	assert(data ~= nil)
	local f = matches[data]
	if f == nil then
		error("non-exhaustive match: " .. tostring(data))
	end
	local t = type(f)
	if t ~= "function" then
		error("match handler type error, got " .. t .. ": " .. tostring(data))
	end
	return f()
end

local setup_main_callback = function(data, raw, main_prompt)
	local cancel = {}

	-- table used to signal out that the user requested a stop on input handling.
	local stop_flag = {}

	-- the user types shorthand group names after defining them.
	-- they could be some letters or a number - anything really.
	-- unlike the long group name, they're not written to disk anywhere,
	-- so they don't have to be "safe" -
	-- if the user can type it once at creation, they can type it again.
	local shorthand_lut = {}

	local function main_callback(response, print)
		-- user hit ctrl-d, request stop.
		if not response then
			stop_flag.stop = true
			return cancel
		end

		-- just reprompt if the user enters nothing -
		-- by definition there's no default action.
		if #response == 0 then
			return
		end

		-- special action or...?
		local special = reserved[response]
		if special then
			local r = match(special, {
				newgroup = function()
					error("ENOTIMPL")
				end,
				ignore = function()
					-- just skip this item by breaking out,
					-- but the overall stop flag is _not_ set.
					return cancel
				end,
			})
			if r then return r end
		end

		-- otherwise, it's a shorthand group name.
		-- look it up and insert it into the group if it exists.
		-- if it does, then request input loop cancel for this item.
		-- TODO: do we want some sort of duplicate detection or signalling?
		-- (may not be handled here anyway...)
		-- but first...
		-- check for blank lines via sanitise like done for the main loop.
		-- if that return nil to signify empty, just skip it.
		local echo = sanitise(response)
		if not echo then return end

		local group = shorthand_lut[response]
		if not group then
			-- group not found? tell the user to try again...
			print("group shorthand " .. echo .. " not found.")
			return
		else
			group[raw] = true
		end
	end

	return main_callback, cancel, stop_flag
end







local ask_about = function(data, display_name, raw)
	local main_prompt = display_name .. " : "
	local callback, cancel, stop_flag = setup_main_callback(data, raw, main_prompt)
	prompt_loop(callback, main_prompt, cancel)
	return stop_flag.stop
end

-- fuck knows what happens if the terminal is stdin.
-- line buffering mayhem, likely.
-- but lua's builtins provide no way to detect this situation.
local data = {}
for raw_input in io.stdin:lines() do
	display_name = sanitise(raw_input)
	if display_name then
		local stop = ask_about(data, display_name, raw_input)
		if stop then break end
	end
end


