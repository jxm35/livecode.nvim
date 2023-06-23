local sc = require("livecode.command.stop_client")
local ss = require("livecode.command.stop_server")

local function StopAllCommand()
	if Client ~= nil then
		sc.StopClientCommand()
	end
	if LCState.server ~= nil then
		ss.StopServerCommand()
	end
end
return {
	StopAllCommand = StopAllCommand,
}
