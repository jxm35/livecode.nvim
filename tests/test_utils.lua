local function setUpBuffer(input)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_command("buffer " .. buf)

	vim.api.nvim_buf_set_lines(0, 0, -1, true, vim.split(input, "\n"))
end

local function setup_test_client()
	local testModule = require("livecode")
	local ws_util = require("lua.livecode.websocket.websocket")
	local client_util = require("lua.livecode.websocket.client")

	local client = ws_util.newWebsocket("127.0.0.1", 11359, false)
	client:set_conn_callbacks(client_util.default_client_callbacks(client))
    -- client:connect()
	return client
end

local function getBufLines()
	local result = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
	return result
end

return {
    setUpBuffer = setUpBuffer,
    setup_test_client = setup_test_client,
    getBufLines = getBufLines
}