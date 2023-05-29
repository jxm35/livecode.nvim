local ot = require("livecode.operational-transformation")
local util = require("livecode.util")
local client_util = require("livecode.websocket.client")

local function SetActiveBuffer()
	if Client == nil then
		error("nil Client - please join a session before changing the buffer")
	end
	local success = client_util.client_attach_to_buffer(Client)

	local fullname = vim.api.nvim_buf_get_name(0)
	local cwdname = vim.api.nvim_call_function("fnamemodify", { fullname, ":." }) -- filepath relative to current working directory
	local bufname = cwdname

	bufname = vim.api.nvim_call_function("fnamemodify", { fullname, ":t" }) -- split off everything before the last '/'
	--                      end
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true) --current buf, start line, last line,

	local obj = {
		util.MESSAGE_TYPE.BUFFER_CONTENT,
		-1,
		bufname,
		"pidslist",
		lines,
	}
	local encoded = vim.json.encode(obj)
	Client.active_conn:send_message(encoded)
end

return {
	SetActiveBuffer = SetActiveBuffer,
}
