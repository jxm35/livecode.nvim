local util = require("livecode.util")
local ot = require("livecode.operational-transformation")
local sc = require("livecode.command.start_client")
local ss = require("livecode.command.start_server")

local function StartSessionCommand(host, port)
	local port = port or 11359
	local server = ss.StartServerCommand("0.0.0.0", port)
	print("session created...")
	local client = sc.StartClientCommand("127.0.0.1", port)
	print("good to go....")
end
return {
	StartSessionCommand = StartSessionCommand,
}
