local util = require("livecode.util")
local ot = require("livecode.operational-transformation")
local sc = require("livecode.command.start_client")
local ss = require("livecode.command.start_server")

local function StopClientCommand()
	if LCState.client == nil then
		error("you are not connected to a session")
	end
	LCState.client.active_conn.sock:close()
	LCState.client = nil
end
return {
	StopClientCommand = StopClientCommand,
}
