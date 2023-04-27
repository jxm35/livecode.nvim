local bit = require("bit")
local util = require("livecode.util")

local function Client(opt)
	local uri = opt.host or "127.0.0.1"
	local iptable = vim.loop.getaddrinfo(uri)
	if #iptable == 0 then
		print("Could not resolve address")
		return
	end
	local ipentry = iptable[1]

	local port = opt.port or 80

	local client = vim.loop.new_tcp()

	local chunk_buffer = ""

	local on_disconnect

	local split_length = opt.split_length or 8192

	local websocket_impl = {}

	local original_type = type
	type = function(obj)
		local otype = original_type(obj)
		if otype == "table" and getmetatable(obj) == websocket_impl then
			return "client"
		end
		return otype
	end

	function websocket_impl:connect(callbacks)
		local ret, err = client:connect(
			ipentry.addr,
			port,
			vim.schedule_wrap(function(err)
				on_disconnect = callbacks.on_disconnect

				if err then
					if on_disconnect then
						on_disconnect()
					end

					error("There was an error during connection: " .. err)
					return
				end

				local function getdata(amount)
					while string.len(chunk_buffer) < amount do
						coroutine.yield()
					end
					local retrieved = string.sub(chunk_buffer, 1, amount)
					chunk_buffer = string.sub(chunk_buffer, amount + 1)
					return retrieved
				end

				local wsread_co = coroutine.create(function()
					while true do
						local wsdata = ""
						local fin

						local rec = getdata(2)
						local b1 = string.byte(string.sub(rec, 1, 1))
						local b2 = string.byte(string.sub(rec, 2, 2))
						local opcode = bit.band(b1, 0xF)
						fin = bit.rshift(b1, 7)

						local paylen = bit.band(b2, 0x7F)
						if paylen == 126 then -- 16 bits length
							local rec = getdata(2)
							local b3 = string.byte(string.sub(rec, 1, 1))
							local b4 = string.byte(string.sub(rec, 2, 2))
							paylen = bit.lshift(b3, 8) + b4
						elseif paylen == 127 then
							paylen = 0
							local rec = getdata(8)
							for i = 1, 8 do -- 64 bits length
								paylen = bit.lshift(paylen, 8)
								paylen = paylen + string.byte(string.sub(rec, i, i))
							end
						end

						--read_mask
						local mask = {}
						local rec = getdata(4)
						for i = 1, 4 do
							table.insert(mask, string.byte(string.sub(rec, i, i)))
						end
						--read_payload
						local data = getdata(paylen)
						--unmask_data
						local unmasked = util.unmask_text(data, mask)
						data = util.convert_bytes_to_string(unmasked)

						wsdata = data

						while fin == 0 do
							local rec = getdata(2)
							local b1 = string.byte(string.sub(rec, 1, 1))
							local b2 = string.byte(string.sub(rec, 2, 2))
							fin = bit.rshift(b1, 7)

							local paylen = bit.band(b2, 0x7F)
							if paylen == 126 then -- 16 bits length
								local rec = getdata(2)
								local b3 = string.byte(string.sub(rec, 1, 1))
								local b4 = string.byte(string.sub(rec, 2, 2))
								paylen = bit.lshift(b3, 8) + b4
							elseif paylen == 127 then
								paylen = 0
								local rec = getdata(8)
								for i = 1, 8 do -- 64 bits length
									paylen = bit.lshift(paylen, 8)
									paylen = paylen + string.byte(string.sub(rec, i, i))
								end
							end

							--read_mask
							local mask = {}
							local rec = getdata(4)
							for i = 1, 4 do
								table.insert(mask, string.byte(string.sub(rec, i, i)))
							end
							--read_payload
							local data = getdata(paylen)
							--unmask_data
							local unmasked = unmask_text(data, mask)
							data = util.convert_bytes_to_string(unmasked)

							wsdata = wsdata .. data
						end

						if opcode == 0x1 then
							if callbacks.on_text then
								callbacks.on_text(wsdata)
							end
						end
					end
				end)

				client:read_start(vim.schedule_wrap(function(err, chunk)
					if err then
						if on_disconnect then
							on_disconnect()
						end

						error("There was an error during connection: " .. err)
						return
					end

					if chunk then
						chunk_buffer = chunk_buffer .. chunk
						coroutine.resume(wsread_co)
					end
				end))
				if callbacks.on_connect then
					callbacks.on_connect()
				end
			end)
		)

		if not ret then
			error(err)
		end
	end

	function websocket_impl:disconnect()
		local mask = {}
		for i = 1, 4 do
			table.insert(mask, math.random(0, 255))
		end

		local frame = {
			0x88,
			0x80,
		}
		for i = 1, 4 do
			table.insert(frame, mask[i])
		end
		local s = util.convert_bytes_to_string(frame)

		client:write(s)

		client:close()
		client = nil

		if on_disconnect then
			on_disconnect()
		end
	end

	function websocket_impl:send_message(str)
		local mask = {}
		for i = 1, 4 do
			table.insert(mask, math.random(0, 255))
		end

		local masked = util.maskText(str, mask)

		local remain = #masked
		local sent = 0
		while remain > 0 do
			local send = math.min(split_length, remain) -- max size before fragment
			remain = remain - send
			local fin
			if remain == 0 then
				fin = 0x80
			else
				fin = 0
			end

			local opcode
			if sent == 0 then
				opcode = 1
			else
				opcode = 0
			end

			local frame = {
				fin + opcode,
				0x80,
			} -- 1, 128 to start with

			-- write the length of the frame
			if send <= 125 then
				frame[2] = frame[2] + send
			elseif send < math.pow(2, 16) then -- 65,536
				frame[2] = frame[2] + 126 -- becomes 254
				local b1 = bit.rshift(send, 8) -- stays as 0
				local b2 = bit.band(send, 0xFF) -- 0
				table.insert(frame, b1)
				table.insert(frame, b2)
			else
				frame[2] = frame[2] + 127 -- becomes 255
				for i = 0, 7 do
					local b = bit.band(bit.rshift(send, (7 - i) * 8), 0xFF)
					table.insert(frame, b)
				end
			end

			for i = 1, 4 do
				table.insert(frame, mask[i])
			end

			for i = sent + 1, sent + 1 + (send - 1) do
				table.insert(frame, masked[i])
			end

			local s = util.convert_bytes_to_string(frame)

			client:write(s)

			sent = sent + send
		end
	end

	function websocket_impl:is_active()
		return client and client:is_active()
	end

	return setmetatable({}, { __index = websocket_impl })
end

return Client
