local websocket_util = require("livecode.websocket.websocket")
local util = require("livecode.util")
local ot = require("livecode.operational-transformation")

local function StartClientCommand(host, port)
    local host = host or "127.0.0.1"
	local port = port or 11359
	local username = "james"
    local client = websocket_util.newWebsocket(host, port, false)
    local callbacks = {
		on_connect = function()
			local obj = {
				util.MESSAGE_TYPE.CONNECT,
				username,
			}
			local encoded = vim.json.encode(obj)
			client.active_conn:send_message(encoded)

			for _, o in pairs(client.api_attach) do
				if o.on_connect then
					o.on_connect()
				end
			end
			print("Attempting to connect...")
		end,

		on_text = function(wsdata)
			vim.schedule(function()
				local decoded = vim.json.decode(wsdata)
				if decoded then
					if decoded[1] == util.MESSAGE_TYPE.INFO then
						print("Recieved: " .. decoded[2])
					elseif decoded[1] == util.MESSAGE_TYPE.WELCOME then
						if decoded[2] == true then
							print("I'm first")
							local success = vim.api.nvim_buf_attach(0, false, {
								on_bytes = function(
									_,
									buf,
									changedtick,
									start_row,
									start_column,
									byte_offset,
									old_end_row,
									old_end_column,
									old_byte_length,
									new_end_row,
									new_end_column,
									new_byte_length
								)
									if client.DETACH then
										return true
									end
									if client.ignore_ticks[changedtick] then
										print("skipping tick: " .. changedtick)
										client.ignore_ticks[changedtick] = nil
										return
									end

									print("doing tick: " .. changedtick)
									print(
										start_row .. "," .. start_column .. "," .. old_end_row .. "," .. old_end_column
									)
									print(new_end_row .. "," .. new_end_column)
									local newbytes = vim.api.nvim_buf_get_text(
										0,
										start_row,
										start_column,
										start_row + new_end_row,
										start_column + new_end_column,
										{}
									)
									-- for i,v in ipairs(newbytes) do
									--     print("char " .. i .. " '" .. newbytes[i] .. "'")
									-- end
									-- print("len " .. #newbytes)
									print("tick: " .. changedtick)
									local operationType = ot.OPERATION_TYPE.INSERT
									if new_end_row < old_end_row then
										operationType = ot.OPERATION_TYPE.DELETE
									elseif new_end_row == old_end_row and new_end_column < old_end_column then
										operationType = ot.OPERATION_TYPE.DELETE
									end
									local operation = ot.newOperation(
										operationType,
										start_row,
										start_column,
										old_end_row,
										old_end_column,
										newbytes
									)
									if client.sent_changes == nil then
										operation:send(client.active_conn)
										client.sent_changes = operation
										print("sent operation")
									else
										client.pending_changes:push(operation)
										print("pushed op to pending")
									end
								end,
							})
						else
							local req = {
								util.MESSAGE_TYPE.GET_BUFFER,
							}
							local encoded = vim.json.encode(req)
							client.active_conn:send_message(encoded)
						end
					elseif decoded[1] == util.MESSAGE_TYPE.GET_BUFFER then
						print("buffer requested.")
						local fullname = vim.api.nvim_buf_get_name(0)
						local cwdname = vim.api.nvim_call_function("fnamemodify", { fullname, ":." }) -- filepath relative to current working directory
						local bufname = cwdname
						--if bufname == fullname then

						bufname = vim.api.nvim_call_function("fnamemodify", { fullname, ":t" }) -- split off everything before the last '/'
						--                      end
						local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true) --current buf, start line, last line,
						local rem = { client.agent, bufname }

						local obj = {
							util.MESSAGE_TYPE.BUFFER_CONTENT,
							decoded[2],
							bufname,
							"pidslist",
							lines,
						}
						local encoded = vim.json.encode(obj)
						client.active_conn:send_message(encoded)
					elseif decoded[1] == util.MESSAGE_TYPE.BUFFER_CONTENT then
						print("loading new buffer")
						local _, _, bufname, pidslist, content = unpack(decoded)
						local buf = vim.api.nvim_create_buf(true, false)
						vim.api.nvim_win_set_buf(0, buf)
						vim.api.nvim_buf_set_name(buf, "[livecode] " .. bufname)
						vim.api.nvim_buf_set_lines(buf, 0, -1, true, content)
						vim.api.nvim_exec("filetype detect", false)

						--Attach to buffer

						local success = vim.api.nvim_buf_attach(0, false, {
							on_bytes = function(
								_,
								buf,
								changedtick,
								start_row,
								start_column,
								byte_offset,
								old_end_row,
								old_end_column,
								old_byte_length,
								new_end_row,
								new_end_column,
								new_byte_length
							)
								if client.DETACH then
									return true
								end
								if client.ignore_ticks[changedtick] then
									client.ignore_ticks[changedtick] = nil
									return
								end
								print(start_row .. "," .. start_column .. "," .. old_end_row .. "," .. old_end_column)
								print(new_end_row .. "," .. new_end_column)
								local newbytes = vim.api.nvim_buf_get_text(
									0,
									start_row,
									start_column,
									start_row + new_end_row,
									start_column + new_end_column,
									{}
								)
								print(vim.inspect(newbytes))
								local operationType = ot.OPERATION_TYPE.INSERT
								if new_end_row < old_end_row then
									operationType = ot.OPERATION_TYPE.DELETE
								elseif new_end_row == old_end_row and new_end_column < old_end_column then
									operationType = ot.OPERATION_TYPE.DELETE
								end
								local operation = ot.newOperation(
									operationType,
									start_row,
									start_column,
									old_end_row,
									old_end_column,
									newbytes
								)
								if client.sent_changes == nil then
									operation:send(client.active_conn)
									client.sent_changes = operation
									print("sent operation")
								else
									client.pending_changes:push(operation)
									print("pushed op to pending")
								end
							end,
						})
					elseif decoded[1] == util.MESSAGE_TYPE.ACK then
						--validate they are the same,
						print("ack Recieved")
						client.last_synced_revision = decoded[2]
						client.sent_changes = nil
						if client.pending_changes:isEmpty() == false then
							local operation = client.pending_changes:dequeue()
							operation:send(client.active_conn)
							client.sent_changes = operation
							print("new operation sent")
						end
					elseif decoded[1] == util.MESSAGE_TYPE.EDIT then
						local operation = ot.newOperationFromMessage(decoded[2])
						if client.sent_changes ~= nil then
							error("should nutil.reallign")
							operation = util.realignOperations(client.sent_changes, operation)
						end

						operation:execute(client.ignore_ticks)
						print("char added")
					else
						error("Unknown message " .. vim.inspect(decoded))
					end
				end
			end)
		end,
		on_disconnect = function()
			vim.schedule(function()
				print("disconnected")
			end)
		end,
	}
    client:set_conn_callbacks(callbacks)
    client:connect()
	Client = client
end

return {
    StartClientCommand = StartClientCommand
}