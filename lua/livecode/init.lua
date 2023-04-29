-- local test = require("livecode.test-module")
--local serve = require('livecode.server')
-- local server = require("livecode.server")
-- local client = require("livecode.client")
local command = require("livecode.command")

local function make_commands()
	vim.cmd([[command! -nargs=* LCStartServer lua require('livecode.server').StartServer(<f-args>)]])
	vim.cmd([[command! -nargs=* LCJoinServer lua require('livecode.client').join(<f-args>)]])
end

local config = {}
if not config.disable_commands then
	make_commands()
end

return {
	-- test = test,
	-- startServer = server.StartServer,
	-- stopServer = server.StopServer,
	-- start = client.start,
	-- join = client.join,
	-- stop = client.stop,
	StartServer = command.StartServerCommand,
	Join = command.StartClientCommand,
	StartSession = command.StartSessionCommand,
}
