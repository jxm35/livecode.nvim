local util = require("livecode.util")
local ot = require("livecode.operational-transformation")
local sc = require("livecode.command.start_client")
local ss = require("livecode.command.start_server")

local function StopServerCommand()
	if LCState.server == nil then
		error("you do not have a server running")
	end
	local confirm = vim.fn.input(
		"The server is running from this machine, leaving will cause the session to end for everyone. (type y to confirm)"
	)
	if confirm == "y" then
		for _, client in pairs(LCState.server.connections) do
			client.sock:close()
		end
		LCState.server:close()
		LCState.server = nil
		print("")
		print("session ended")
	end
end
return {
	StopServerCommand = StopServerCommand,
}
