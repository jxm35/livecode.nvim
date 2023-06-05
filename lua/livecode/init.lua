local command = require("livecode.command")
local state = require("livecode.state")

local function make_commands()
	vim.cmd([[command! -nargs=* LCStartSession lua require('livecode.command').StartServerCommand(<f-args>)]])
	vim.cmd([[command! -nargs=* LCJoin lua require('livecode.command').StartClientCommand(<f-args>)]])
	vim.cmd([[command! -nargs=* LCShareBuffer lua require('livecode.command').SetActiveBuffer(<f-args>)]])
	vim.cmd([[command! -nargs=* LCStop lua require('livecode.command').StartClientCommand(<f-args>)]])
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
