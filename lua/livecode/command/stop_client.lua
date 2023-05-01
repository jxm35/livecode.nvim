local util = require("livecode.util")
local ot = require("livecode.operational-transformation")
local sc = require("livecode.command.start_client")
local ss = require("livecode.command.start_server")

local function StopClientCommand()
    if Client == nil then
        error("you are not connected to a session")
       end
       Client.active_conn.sock:close()
       Client = nil
end
return {
    StopClientCommand = StopClientCommand
}