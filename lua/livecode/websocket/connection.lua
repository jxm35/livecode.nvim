local util = require("livecode.util")
local bit = require("bit")

local connection_metatable = {}
connection_metatable.__index = connection_metatable
local split_length = 8192

local function newConnection(id, sock)
	local connection = {
		id = id,
		sock = sock,
	}
	return setmetatable(connection, connection_metatable)
end

local original_type = type
type = function(obj)
	local otype = original_type(obj)
	if otype == "table" and getmetatable(obj) == connection_metatable then
		return "connection"
	end
	return otype
end

function connection_metatable:attach(callbacks)
	self.callbacks = callbacks
end

function connection_metatable:set_socket(sock)
	self.sock = sock
end

function connection_metatable:send_message(str)
	print("sending:" .. str)
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

		-- connections[self.id].sock:write(s)
		self.sock:write(s)
		print("written to: " .. self.id)

		sent = sent + send
	end
end

return {
	newConnection = newConnection,
}
