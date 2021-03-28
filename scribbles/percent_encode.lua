local percent_encode_legal_character = {
	["A"] = true,
	["B"] = true,
	["C"] = true,
	["D"] = true,
	["E"] = true,
	["F"] = true,
	["G"] = true,
	["H"] = true,
	["I"] = true,
	["J"] = true,
	["K"] = true,
	["L"] = true,
	["M"] = true,
	["N"] = true,
	["O"] = true,
	["P"] = true,
	["Q"] = true,
	["R"] = true,
	["S"] = true,
	["T"] = true,
	["U"] = true,
	["V"] = true,
	["W"] = true,
	["X"] = true,
	["Y"] = true,
	["Z"] = true,

	["a"] = true,
	["b"] = true,
	["c"] = true,
	["d"] = true,
	["e"] = true,
	["f"] = true,
	["g"] = true,
	["h"] = true,
	["i"] = true,
	["j"] = true,
	["k"] = true,
	["l"] = true,
	["m"] = true,
	["n"] = true,
	["o"] = true,
	["p"] = true,
	["q"] = true,
	["r"] = true,
	["s"] = true,
	["t"] = true,
	["u"] = true,
	["v"] = true,
	["w"] = true,
	["x"] = true,
	["y"] = true,
	["z"] = true,

	["0"] = true,
	["1"] = true,
	["2"] = true,
	["3"] = true,
	["4"] = true,
	["5"] = true,
	["6"] = true,
	["7"] = true,
	["8"] = true,
	["9"] = true,
	["-"] = true,
	["_"] = true,
	["."] = true,
	["~"] = true,
}



percent_encode = function(s)
	local r = s:gsub(".", function(s2)
		if percent_encode_legal_character[s2] then
			return s2
		else
			local ascii = s2:byte()
			return string.format("%%%02X", ascii)
		end
	end)
	return r
end



