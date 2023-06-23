local command = require("livecode.command")
local state = require("livecode.state")

local function make_commands()
	vim.cmd([[command! -nargs=* LCStartSession lua require('livecode.command').StartServerCommand(<f-args>)]])
	vim.cmd([[command! -nargs=* LCJoin lua require('livecode.command').StartClientCommand(<f-args>)]])
	vim.cmd([[command! -nargs=* LCShareBuffer lua require('livecode.command').SetActiveBuffer(<f-args>)]])
	vim.cmd([[command! -nargs=* LCStop lua require('livecode.command').StopCommand(<f-args>)]])
end

local C = {}

LCState = {
	server = nil,
	client = nil,
	username = ""
}

local default = {
	disable_commands = false,
	username = ""
}

C.config = default

function C.setup(options)
	C.config = vim.tbl_extend("force", C.config, options or {})
	if not C.config.disable_commands then
		make_commands()
	end
end

function C.startSession(port)
	command.StartSessionCommand(port)
end

function C.join(host, port)
	command.StartClientCommand(host, port)
end

function C.shareBuffer()
	command.SetActiveBufferCommand()
end

function C.stop()
	command.StopCommand()
end

return C
