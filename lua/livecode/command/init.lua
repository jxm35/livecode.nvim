local start_server = require("livecode.command.start_server")
local start_client = require("livecode.command.start_client")

return {
    StartServerCommand = start_server.StartServerCommand,
    StartClientCommand = start_client.StartClientCommand,
}