local websocket_util = require("livecode.websocket.websocket")
local util = require("livecode.util")

local function StartServerCommand(host, port)
    local host = host or "0.0.0.0"
	local port = port or 11359

    local server = websocket_util.newWebsocket(host, port, true)
    local callbacks = {
        on_connect = function(conn)
			server.connection_count = server.connection_count + 1

			local function forward_to_other_users(msg)
				print("active conn id: " .. conn.id)
				print(vim.inspect(server.connections))
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
            local conn_callbacks = {
                on_text = function(wsdata)
					vim.schedule(function()
						local decoded = vim.json.decode(wsdata)
						if decoded then
							if decoded[1] == util.MESSAGE_TYPE.CONNECT then
								local forward_msg = {
									util.MESSAGE_TYPE.INFO,
									decoded[2] .. " has joined.",
								}
								local encoded = vim.json.encode(forward_msg)
								forward_to_other_users(encoded)

								local isFirst = true
								if #server.connections > 1 then
									isFirst = false
								end
								local response_msg = {
									util.MESSAGE_TYPE.WELCOME,
									isFirst,
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
								server.pending_changes:push(decoded[2])
								forward_to_other_users(wsdata)
								server.revision_number = server.revision_number + 1
								local response_msg = {
									util.MESSAGE_TYPE.ACK,
									server.revision_number,
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
						server.connection_count = math.max(server.connection_count - 1, 0)
						print("Disconnected. " .. server.connection_count .. " client(s) remaining.")
						if server.connection_count == 0 then
							server.initialised = false
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

            conn:set_callbacks(conn_callbacks)
		end,
    }
    server:set_callbacks(callbacks)
    server:listen()
    print("server listening...")
    print("local - " .. "127.0.0.1" .. ":" .. port)
	print("remote - " .. util.getPublicIp() .. ":" .. port)
    return server
end

return {
    StartServerCommand = StartServerCommand
}