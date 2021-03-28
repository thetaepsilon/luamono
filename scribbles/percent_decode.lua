

percent_decode = function(s) local r = s:gsub("%%(..)", function(s2) return string.char(assert(tonumber(s2, 16), "bad percent encoded hex")) end) return r end
