local bit = require("bit")

local function maskText(str, mask)
	local masked = {}
	for i = 0, #str - 1 do
		local j = bit.band(i, 0x3)
		local trans = bit.bxor(string.byte(string.sub(str, i + 1, i + 1)), mask[j + 1])
		table.insert(masked, trans)
	end
	return masked
end

local function nocase(s)
	s = string.gsub(s, "%a", function(c)
		if string.match(c, "[a-zA-Z]") then
			return string.format("[%s%s]", string.lower(c), string.upper(c))
		else
			return c
		end
	end)
	return s
end

local function convert_bytes_to_string(tab)
	local s = ""
	for _, el in ipairs(tab) do
		s = s .. string.char(el)
	end
	return s
end

local function unmask_text(str, mask)
	local unmasked = {}
	for i = 0, #str - 1 do
		local j = bit.band(i, 0x3)
		local trans = bit.bxor(string.byte(string.sub(str, i + 1, i + 1)), mask[j + 1])
		table.insert(unmasked, trans)
	end
	return unmasked
end

local function getPublicIp()
	local output = vim.fn.system({ "ipconfig", "getifaddr", "en0" })
	return output
end


return {
	maskText = maskText,
	nocase = nocase,
	convert_bytes_to_string = convert_bytes_to_string,
	unmask_text = unmask_text,
	getPublicIp = getPublicIp,
}
