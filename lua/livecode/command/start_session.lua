local util = require("livecode.util")
local ot = require("livecode.operational-transformation")
local sc = require("livecode.command.start_client")
local ss = require("livecode.command.start_server")

local function StartSessionCommand(port)
	local port = port or 11359
	local server = ss.StartServerCommand(port)
	local client = sc.StartClientCommand("127.0.0.1", port)
	print("session started")
	print("local - " .. "127.0.0.1" .. ":" .. port)
	local pubIp = "[local ip]"
	if pcall(function()
		util.getPublicIp()
	end) then
		pubIp = util.getPublicIp()
		pubIp = string.gsub(pubIp, "%s+", " ")
		print(vim.inspect(pubIp))
		else
			print("To find the local ip of your device, visit www.whatismybrowser.com/detect/what-is-my-local-ip-address.com")
	end
	print("To access this on another device, run ':LCJoin " .. pubIp .. "" ..  port .. "' on another device.")
end
return {
	StartSessionCommand = StartSessionCommand,
}
