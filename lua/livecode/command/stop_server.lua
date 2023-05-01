local util = require("livecode.util")
local ot = require("livecode.operational-transformation")
local sc = require("livecode.command.start_client")
local ss = require("livecode.command.start_server")

local function StopServerCommand()
    if Server == nil then
        error("you do not have a server running")
    end
    local confirm =  vim.fn.input("The server is running from this machine, leaving will cause the session to end for everyone. (press y to confirm)")
    print(confirm)
    for _, client in pairs(Server.connections) do
        client.sock:close()
    end
    Server.server:close()
    Server = nil
end
return {
    StopServerCommand = StopServerCommand
}