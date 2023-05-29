local websocket_util = require("livecode.websocket.websocket")
local client_util = require("livecode.websocket.client")

local function StartClientCommand(host, port)
	local host = host or "127.0.0.1"
	local port = port or 11359

	local client = websocket_util.newWebsocket(host, port, false)
	
	client:set_conn_callbacks(client_util.default_client_callbacks(client))
	
	client:connect()

	Client = client
end


return {
	StartClientCommand = StartClientCommand,
}
