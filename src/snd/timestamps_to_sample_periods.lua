#!/usr/bin/env lua5.1
--[[
converts timestamp files consisting of lines in the following format:
hh:mm:ss.dd hh:mm:ss.dd
...

the input lines are timestamps in an audio file,
denoting time periods in which a simple effect of some kind
(amplication, etc...) should be enabled;
time between these periods is when the effect is disabled.
hh, mm and dd are all optional;
however, if mm is used, ss must be exactly two digits; likewise for hh and mm.
any such time value limited to digits must furthermore be 00 - 59.
this ensures proper sexagesimal time notation.
if any field is omitted, it's separator (: or .) must also be omitted.

the output format is a series of binary uint64's in network byte order.
the topmost bit B encodes enable/disable,
and the remaining 63 bits encode an unsigned 63-bit integer N.
starting from the beginning of the file,
each field says that the effect should be enabled (B = 1) or disabled (B = 0)
for the N next samples in the audio file.
when that period has been processed,
the next line refers to a number of samples from that point, and so on.
]]

local usage = "\n" ..
	"usage: timestamps_to_sample_periods sample_rate\n" ..
		"\tsample_rate must be an integer and a multiple of 100.\n"

local sample_rate = ...
assert(tonumber(sample_rate), usage)
assert(math.fmod(sample_rate, 100) == 0, usage);
local samples_per_frame = sample_rate / 100
--[[
the available precision for timestamps is affected by the sample rate,
as we're not going to try to do any tricky interpolation ourselves here;
we want to remain exact and predictable.
for instance, 44100hz can naturally specify down to 100ths of a second,
whereas 48000hz could do millisecond resolution.
for now as might be inferred from the readme,
we're simply insisting on multiples of 100hz for the sampling rate,
and only supporting two digits of fractional seconds (i.e. 100ths).
]]

-- small helper in the pattern match stuff below...
-- adds a true/false in front of return values from string.match to indicate failure.
-- this is distinguished from the case where true could be returned but no captures.
local function wrap(...)
	local v = ...
	return v ~= nil, ...
end

local match = function(e, s)
	return wrap(s:match(e))
end









-- #### expression matching section #### --

-- yay, input is technically a regular language!
-- however without real regexes (we're missing the alternation | operator)
-- we just need to break things up a bit.
local pat_v60 = "[0-5][0-9]"
local pat_digit = "[0-9]"
local pat_int = pat_digit.."+"
-- yes, we can have just one fraction digit.
local pat_fract = pat_digit .. pat_digit .. "?"

local pat_hours = pat_int
local pat_longmins = pat_int
local pat_longsecs = pat_int
local pat_shortmins = pat_v60
local pat_shortsecs = pat_v60
-- please excuse my mildly broken BNF notation.
-- some terms not defined below due to defining them directly above.
--[[
record := timestamp " " timestamp

timestamp := timestamp_main | timestamp_main "." fract

timestamp_main :=
	(hours ":" shortmins ":" shortsecs) |
	(longmins ":" shortsecs) |
	(longsecs)
]]

-- bail-out helper
local bad = function(str, err)
	error("parser error: " .. err .. ", input in question was " .. str)
end
-- sanity check the number part.
-- it _should_ succeed always, but the "type" of tonumber doesn't tell you that.
local num = function(v)
	return assert(tonumber(v))
end

local pat_fract = "^("..pat_fract..")$"
local parse_fract = function(s)
	-- getting a bit shotgun parser territory here.
	-- however the long list of return tokens would get awkward...
	-- at least it's technically isolated from everything else.
	local fract = s:match(pat_fract)
	if fract then
		-- need to be careful here as it's a fractional value,
		-- however we want to parse it in an integer-like fashion
		-- (to avoid float rounding issues).
		-- so we have to pad out implied zeroes ourself;
		-- as we just checked for one or two digits,
		-- and currently only accept 100ths precision,
		-- this is relatively simple.
		if #fract == 1 then
			fract = fract .. "0"
		end
		return num(fract)
	else
		return bad(s, "invalid fractional seconds")
	end
end

-- as we lack alternation (and the captures would be hairy anyway!),
-- finding a match for one has to be done manually, one at a time.
-- note also the ^ and $; as we only match one specific term,
-- we _must_ match the entire string provided to us.
local pat_timestamp_main_form1 =
	"^("..pat_hours.."):("..pat_shortmins.."):("..pat_shortsecs..")$"
local pat_timestamp_main_form2 =
	"^("..pat_longmins.."):("..pat_shortsecs..")$"
local pat_timestamp_main_form3 =
	"^("..pat_longsecs..")$"

local timestamp_main = function(h, m, s)
	return {
		hours = h, minutes = m, seconds = s,
	}
end
local parse_timestamp_main = function(s)
	-- true regular expressions are first-match greedy anyway in most cases,
	-- as they are unambiguous at alternations.
	-- so just finding the first matching form and assuming that should be fine.
	local hours, mins, secs = s:match(pat_timestamp_main_form1)
	if hours then return timestamp_main(hours, mins, secs) end

	-- note that we'll handle normalisation late
	-- (e.g. hours and minutes combined to a sum total of seconds).
	-- that is not the parser's job.
	-- also yes, the variable shadowing is intentional,
	-- to make the translation to code more mechanical.
	local mins, secs = s:match(pat_timestamp_main_form2)
	if mins then return timestamp_main(nil, mins, secs) end

	local secs = s:match(pat_timestamp_main_form3)
	if secs then return timestamp_main(nil, nil, secs) end

	return bad(s, "invalid non-fractional part of timestamp")
end

local pat_timestamp_form1 = "^([^.]*)%.([^.]*)$"
local pat_timestamp_form2 = "^([^.]*)$"
local parse_timestamp = function(s)
	local main, fract = s:match(pat_timestamp_form1)
	if main then
		return {
			main = parse_timestamp_main(main),
			fract = parse_fract(fract),
		}
	end

	local main = s:match(pat_timestamp_form2)
	if main then
		return {
			main = parse_timestamp_main(main),
		}
	end

	return bad(s, "invalid timestamp")
end

local pat_record = "^([^ ]*) ([^ ]*)$"
local parse_record = function(s)
	-- end is a lua keyword, oops
	local range_start, range_end = s:match(pat_record)
	if range_start then
		return {
			range_start = parse_timestamp(range_start),
			range_end = parse_timestamp(range_end)
		}
	end

	return bad(s, "invalid timestamp range record")
end









-- #### validated input handling section #### --

-- in order to subtract one time range from another, or generally convert them,
-- we want to convert the timestamp to a nice integer first.
-- now, lua _by default_ uses double precision floats for numbers.
-- if we assume that we need ~9 bits to address the number of "frames" in one second
-- (where currently a frame is 1/100th of a second)
-- that leaves us 40 bits (with some headroom) to go to seconds.
-- this results in about 16 billion seconds, or about 34,865 years...
-- safe to say this is likely to be sufficient for now
-- if it ever became a problem on atypical lua compiles,
-- a bigint format could be used.
local normalize = function(timestamp)
	local h = timestamp.main.hours or 0
	local m = timestamp.main.minutes or 0
	local s = timestamp.main.seconds
	local f = timestamp.fract or 0

	local secs = (h * 3600) + (m * 60) + s
	local frames = (s * 100) + f

	return frames
end

local emit_frame_block = function(onoff, framecount, samples_per_frame)
	!?
end









-- now all that is out of the way...
local l = 0
local lerror = function(msg)
	error("input line " .. l .. ": " .. msg)
end
local prev_end = 0
for line in io.stdin:lines() do
	l = l + 1
	local record = parse_record(line)
	local rstart = normalize(record.range_start)
	local rend = normalize(record.range_end)

	if (rstart >= rend) then
		lerror("starting timestamp was same as or greater than end timestamp.")
	end

	-- timestamps are expected to be monotically increasing.
	if (rstart < prev_end) then
		lerror("starting timestamp is before last end timestamp or before start of time.")
	end

	-- if some frames have elapsed since the last period's endpoint,
	-- emit the relevant number of samples in the off state.
	local since = rstart - prev_end
	if (since > 0) then
		emit_frame_block(false, since, samples_per_frame)
	end

	-- then emit the on block for this duration...
	local duration = rend - rstart
	emit_frame_block(true, duration, samples_per_frame)

	-- then save the endpoint timestamp for future blocks.
	prev_end = rend
end


