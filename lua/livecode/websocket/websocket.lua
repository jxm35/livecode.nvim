local bit = require("bit")
local _conn = require("livecode.websocket.connection")
local util = require("livecode.util")

-- local websocket_impl = {}
local websocket_metatable = {}
websocket_metatable.__index = websocket_metatable

local original_type = type
type = function(obj)
	local otype = original_type(obj)
	if otype == "table" and getmetatable(obj) == websocket_metatable then
		return "websocket"
	end
	return otype
end

local function newWebsocket(host, port)
	local server = vim.loop.new_tcp()
	server:bind(host, port)
	local websocket = {
		revision_number = 0,
		pending_changes = util.newQueue(),
		revision_log = nil,
		document_state = nil,

		-----------------
		active_conn = nil,
		callbacks = nil,
		chunk_buffer = "",
		conn_id = 1,
		connection_count = 0,
		connections = {},
		initialised = false,
		host = host,
		port = port,
		server = server,
	}
	return setmetatable(websocket, websocket_metatable)
end

-- getdata reads a given length of data from the websockets chunkbuffer
function websocket_metatable:getdata(amount)
	while string.len(self.chunk_buffer) < amount do
		coroutine.yield()
	end
	local retrieved = string.sub(self.chunk_buffer, 1, amount)
	self.chunk_buffer = string.sub(self.chunk_buffer, amount + 1)
	return retrieved
end

function websocket_metatable:set_callbacks(callbacks)
	self.callbacks = callbacks
end


local read_coroutine = coroutine.create(function(ws)
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
				rec = self:getdata(8)
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
end)

--listen for new connections
function websocket_metatable:listen()
	local ret, err = self.server:listen(128, function(err)
		local sock = vim.loop.new_tcp()
		self.server:accept(sock)

		-- call_callbacks_connected
		if self.callbacks.on_connect then
			self.active_conn = _conn.newConnection(self.conn_id, sock)
			self.connections[self.conn_id] = self.active_conn
			self.conn_id = self.conn_id + 1
			self.callbacks.on_connect(self.active_conn)
		end

		-- register_socket_read_callback
		sock:read_start(function(err, chunk)
			if chunk then
				--read_message_tcp
				self.chunk_buffer = self.chunk_buffer .. chunk
				coroutine.resume(read_coroutine, self)
			else
				-- close_client_callbacks
				if self.active_conn and self.active_conn.callbacks.on_disconnect then
					self.active_conn.callbacks.on_disconnect()
				end
				-- remove_client
				self.connections[self.active_conn.id] = nil
				sock:shutdown()
				sock:close()
			end
		end)
	end)
	if not ret then
		error(err)
	end
end

-- close all connections
function websocket_metatable:close()
	for _, conn in pairs(self.connections) do
		if conn and conn.callbacks.on_disconnect then
			conn.callbacks.on_disconnect()
		end

		conn.sock:shutdown()
		conn.sock:close()
	end

	self.connections = {}

	if self.server then
		self.server:close()
		self.server = nil
	end
end
---- client functions

-- connect to existing socket
function websocket_metatable:connect(client, host, port, callbacks)
	local ret, err = client:connect(
		host,
		port,
		vim.schedule_wrap(function(err)
			self.on_disconnect = callbacks.on_disconnect

			if err then
				if self.on_disconnect then
					self.on_disconnect()
				end

				error("There was an error during connection: " .. err)
				return
			end

			local wsread_co = coroutine.create(function()
				while true do
					local wsdata = ""
					local fin

					local rec = self:getdata(2)
					local b1 = string.byte(string.sub(rec, 1, 1))
					local b2 = string.byte(string.sub(rec, 2, 2))
					local opcode = bit.band(b1, 0xF)
					fin = bit.rshift(b1, 7)

					local paylen = bit.band(b2, 0x7F)
					if paylen == 126 then -- 16 bits length
						rec = self:getdata(2)
						local b3 = string.byte(string.sub(rec, 1, 1))
						local b4 = string.byte(string.sub(rec, 2, 2))
						paylen = bit.lshift(b3, 8) + b4
					elseif paylen == 127 then
						paylen = 0
						rec = self:getdata(8)
						for i = 1, 8 do -- 64 bits length
							paylen = bit.lshift(paylen, 8)
							paylen = paylen + string.byte(string.sub(rec, i, i))
						end
					end

					--read_mask
					local mask = {}
					rec = self:getdata(4)
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
						rec = self:getdata(2)
						b1 = string.byte(string.sub(rec, 1, 1))
						b2 = string.byte(string.sub(rec, 2, 2))
						fin = bit.rshift(b1, 7)

						local paylen = bit.band(b2, 0x7F)
						if paylen == 126 then -- 16 bits length
							local rec = self:getdata(2)
							local b3 = string.byte(string.sub(rec, 1, 1))
							local b4 = string.byte(string.sub(rec, 2, 2))
							paylen = bit.lshift(b3, 8) + b4
						elseif paylen == 127 then
							paylen = 0
							local rec = self:getdata(8)
							for i = 1, 8 do -- 64 bits length
								paylen = bit.lshift(paylen, 8)
								paylen = paylen + string.byte(string.sub(rec, i, i))
							end
						end

						--read_mask
						mask = {}
						rec = self:getdata(4)
						for i = 1, 4 do
							table.insert(mask, string.byte(string.sub(rec, i, i)))
						end
						--read_payload
						data = self:getdata(paylen)
						--unmask_data
						unmasked = util.unmask_text(data, mask)
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
					if self.on_disconnect then
						self.on_disconnect()
					end

					error("There was an error during connection: " .. err)
					return
				end

				if chunk then
					self.chunk_buffer = self.chunk_buffer .. chunk
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

return {
	newWebsocket = newWebsocket
}

