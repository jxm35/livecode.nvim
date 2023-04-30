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


local read_helper = function(ws)
	if type(ws) ~= "websocket" then
		error(type(ws) .. "is not a websocket")
	end
	while true do
		local wsdata = ""
		local fin

		--read_header_two_bytes_first
		local rec = ws:getdata(2)
		local b1 = string.byte(string.sub(rec, 1, 1))
		local b2 = string.byte(string.sub(rec, 2, 2))
		local opcode = bit.band(b1, 0xF)
		fin = bit.rshift(b1, 7)
		--read_payload_length
		local paylen = bit.band(b2, 0x7F)
		if paylen == 126 then -- 16 bits length
			rec = ws:getdata(2)
			local b3 = string.byte(string.sub(rec, 1, 1))
			local b4 = string.byte(string.sub(rec, 2, 2))
			paylen = bit.lshift(b3, 8) + b4
		elseif paylen == 127 then
			paylen = 0
			rec = ws:getdata(8)
			for i = 1, 8 do -- 64 bits length
				paylen = bit.lshift(paylen, 8)
				paylen = paylen + string.byte(string.sub(rec, i, i))
			end
		end
		--read_mask
		local mask = {}
		rec = ws:getdata(4)
		for i = 1, 4 do
			table.insert(mask, string.byte(string.sub(rec, i, i)))
		end
		--read_payload
		local data = ws:getdata(paylen)
		--unmask_data
		local unmasked = util.unmask_text(data, mask)
		data = util.convert_bytes_to_string(unmasked)

		wsdata = data

		while fin == 0 do
			--read_header_two_bytes_fragmented
			rec = ws:getdata(2)
			b1 = string.byte(string.sub(rec, 1, 1)) -- will be
			b2 = string.byte(string.sub(rec, 2, 2))
			fin = bit.rshift(b1, 7) -- becomes 1 if this is the last frame
			--read_payload_length
			local paylen = bit.band(b2, 0x7F) -- 127,
			if paylen == 126 then -- 16 bits length
				rec = ws:getdata(2)
				local b3 = string.byte(string.sub(rec, 1, 1))
				local b4 = string.byte(string.sub(rec, 2, 2))
				paylen = bit.lshift(b3, 8) + b4
			elseif paylen == 127 then
				paylen = 0
				rec = ws:getdata(8)
				for i = 1, 8 do -- 64 bits length
					paylen = bit.lshift(paylen, 8)
					paylen = paylen + string.byte(string.sub(rec, i, i))
				end
			end
			--read_mask
			mask = {}
			rec = ws:getdata(4)
			for i = 1, 4 do
				table.insert(mask, string.byte(string.sub(rec, i, i)))
			end
			--read_payload
			local data = ws:getdata(paylen)
			--unmask_data
			unmasked = util.unmask_text(data, mask)
			data = util.convert_bytes_to_string(unmasked)

			wsdata = wsdata .. data
		end

		if opcode == 0x1 then
			if ws.active_conn and ws.active_conn.callbacks.on_text then
				ws.active_conn.callbacks.on_text(wsdata)
			end
		end
		if opcode == 0x8 then -- CLOSE
			--close_client_callbacks
			if ws.active_conn and ws.active_conn.callbacks.on_disconnect then
				ws.active_conn.callbacks.on_disconnect()
			end
			--remove_client
			ws.connections[ws.active_conn.id] = nil
			ws.connections.sock:close() -- this could cause errors
			break
		end
	end
end


return {
	maskText = maskText,
	nocase = nocase,
	convert_bytes_to_string = convert_bytes_to_string,
	unmask_text = unmask_text,
	getPublicIp = getPublicIp,
	read_helper =  read_helper
}
