local command = require("livecode.command")
local state = require("livecode.state")

local function make_commands()
	vim.cmd([[command! -nargs=* LCStartServer lua require('livecode.server').StartServer(<f-args>)]])
	vim.cmd([[command! -nargs=* LCJoinServer lua require('livecode.client').join(<f-args>)]])
end

local config = {}
if not config.disable_commands then
	make_commands()
end

return {
	StartServer = command.StartServerCommand,
	Join = command.StartClientCommand,
	StartSession = command.StartSessionCommand,
	SetActiveBuffer = command.SetActiveBufferCommand,
	Stop = command.StopCommand,
}
