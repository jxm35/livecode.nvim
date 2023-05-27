local websocket_util = require("livecode.websocket.websocket")
local util = require("livecode.util")
local server_util = require("livecode.websocket.server")


local function StartServerCommand(host, port)
	local host = host or "0.0.0.0"
	local port = port or 11359

	local server = websocket_util.newWebsocket(host, port, true)

	server:set_callbacks(server_util.default_server_callbacks(server))

	server:listen()

	print("server listening...")
	print("local - " .. "127.0.0.1" .. ":" .. port)
	print("remote - " .. util.getPublicIp() .. ":" .. port)
	Server = server
end

return {
	StartServerCommand = StartServerCommand,
}
