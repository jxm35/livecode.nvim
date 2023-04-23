local websocket_server = require("livecode.websocket.server")
local util = require("livecode.util")

local num_connected = 0
local server

-- Operational Transaction Necessities
local revision_number = 0
local pending_changes = util.newQueue() -- recieved but not processed
local revision_log --log of all processed changes
local document_state -- at last revision

local function StartServer(host, port)
	local host = host or "127.0.0.1"
	local port = port or 11359

	server = websocket_server { host = host, port = port }

	server:listen {
		on_connect = function(conn)
			num_connected = num_connected + 1

			local function forward_to_other_users(msg)
				for id, client in pairs(server.connections) do
					if id ~= conn.id then
						client:send_message(msg)
					end
				end
			end

			local function forward_to_one_user(msg)
				for id, client in pairs(server.connections) do
					if id ~= conn.id then
						client:send_message(msg)
						break
					end
				end
			end
       
			conn:attach {
				on_text = function(wsdata)
					vim.schedule(function()
						local decoded = vim.json.decode(wsdata)
						if decoded then
							if decoded[1] == util.MESSAGE_TYPE.CONNECT then
								local forward_msg = {
									util.MESSAGE_TYPE.INFO,
									decoded[2] .. " has joined."
								}
								local encoded = vim.json.encode(forward_msg)
								forward_to_other_users(encoded)

								local isFirst = true
								if #server.connections > 1 then
									isFirst = false
								end
								local response_msg = {
									util.MESSAGE_TYPE.WELCOME,
									isFirst
								}
								encoded = vim.json.encode(response_msg)
            					conn:send_message(encoded)
								print(decoded[2] .. " has joined.")

							elseif decoded[1] == util.MESSAGE_TYPE.GET_BUFFER then
								forward_to_one_user(wsdata)

							elseif decoded[1] == util.MESSAGE_TYPE.BUFFER_CONTENT then
								print("forwarding buffer content")
								forward_to_other_users(wsdata)

							elseif decoded[1] == util.MESSAGE_TYPE.INFO then
								forward_to_other_users(wsdata)

							elseif decoded[1] == util.MESSAGE_TYPE.EDIT then
								pending_changes:push(decoded[2])
								forward_to_other_users(wsdata)
								revision_number = revision_number + 1
								local response_msg = {
									util.MESSAGE_TYPE.ACK,
									revision_number
								}
								local encoded = vim.json.encode(response_msg)
            					conn:send_message(encoded)
								print("forwarded and responeded")

							else
								error("Unknown message " .. vim.inspect(decoded))
							end
						end
					end)
				end,
				on_disconnect = function()
					vim.schedule(function()
						num_connected = math.max(num_connected - 1, 0)
						print("Disconnected. " .. num_connected .. " client(s) remaining.")
						if num_connected  == 0 then
							is_initialized = false
						end

						local disconnect = {
							util.MESSAGE_TYPE.INFO,
							conn.id .. "has disconnected",
						}
						local encoded = vim.json.encode(disconnect)
						forward_to_other_users(encoded)

					end)
				end,
			}

		end
	}
	print("Server is listening on port " .. port .. "...")
end

local function StopServer()
	vim.schedule(function()
		server:close()
		num_connected = 0
		print("Server shutdown.")
	end)
end


return {
	StartServer = StartServer,
	StopServer = StopServer,
}
