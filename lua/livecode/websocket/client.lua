local util = require("livecode.util.message")
local ot = require("livecode.operational-transformation")

local function client_attach_to_buffer(client)
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
			-- print(start_row .. "," .. start_column .. "," .. old_end_row .. "," .. old_end_column)
			-- print(new_end_row .. "," .. new_end_column)
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
			local operation = ot.newOperationExtended(
				operationType,
				start_row,
				start_column,
				old_end_row,
				old_end_column,
				new_end_row,
				new_end_column,
				newbytes
			)
			if client.sent_changes == nil then
				operation:send(client.active_conn, client.last_synced_revision)
				client.sent_changes = operation
				print("sent operation")
			else
				client.pending_changes:push(operation)
				print("pushed op to pending")
			end
		end,
	})
	return success
end

local function client_on_connect(client)
    local obj = {
		util.MESSAGE_TYPE.CONNECT,
		"username",
	}
	local encoded = vim.json.encode(obj)
	client.active_conn:send_message(encoded)

	for _, o in pairs(client.api_attach) do
		if o.on_connect then
			o.on_connect()
		end
	end
	print("Attempting to connect...")
end

local function client_on_message_receive(client, wsdata)
    vim.schedule(function()
		local decoded = vim.json.decode(wsdata)
		if decoded then
			if decoded[1] == util.MESSAGE_TYPE.INFO then
				print("Recieved: " .. decoded[2])

			elseif decoded[1] == util.MESSAGE_TYPE.WELCOME then
				if decoded[2] == true then
					print("I'm first")
					local success = client_attach_to_buffer(client)
					if success == false then
						error("could not connect to buffer")
					end
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
				local _, _, bufname, pidslist, content, lsr = unpack(decoded)
				client.last_synced_revision = lsr
				local buf = vim.api.nvim_create_buf(true, false)
				vim.api.nvim_win_set_buf(0, buf)
				vim.api.nvim_buf_set_name(buf, "[livecode] " .. bufname)
				vim.api.nvim_buf_set_lines(buf, 0, -1, true, content)
				vim.api.nvim_exec("filetype detect", false)

				--Attach to buffer

				local success = client_attach_to_buffer(client)
				if success == false then
					error("could not connect to buffer")
				end
				
			elseif decoded[1] == util.MESSAGE_TYPE.ACK then
				--validate they are the same,
				print("ack Recieved")
				client.last_synced_revision = decoded[2]
				print(
					"setting processed: " .. client.sent_changes.character[1],
					", " .. client.sent_changes.start_row .. "revision: " .. client.last_synced_revision
				)
				client.processed_changes[client.last_synced_revision] = client.sent_changes
				client.sent_changes = nil
				if client.pending_changes:isEmpty() == false then
					local operation = client.pending_changes:dequeue()
					operation:send(client.active_conn, client.last_synced_revision)
					client.sent_changes = operation
					print("new operation sent")
				end

			elseif decoded[1] == util.MESSAGE_TYPE.EDIT then
				local operation = ot.newOperationFromMessage(decoded[2])
				local change_revision = decoded[3]
				client.last_synced_revision = decoded[4]
				print(
					"recieved: "
						.. operation.start_row
						.. ","
						.. operation.start_column
						.. ","
						.. operation.end_row
						.. ","
						.. operation.end_column
				)
				print(operation.new_end_row .. "," .. operation.new_end_column)
				-- iterate through processed_changes
				if operation.operationType == ot.OPERATION_TYPE.DELETE then
					print("received revision: '" .. change_revision .. "'")
				end
				for i = change_revision + 1, client.last_synced_revision, 1 do
					if client.processed_changes[i] ~= nil then
						operation = ot.realignOperations(client.processed_changes[i], operation)
					end
				end
				if client.sent_changes ~= nil then
					operation = ot.realignOperations(client.sent_changes, operation)
					if client.pending_changes:isEmpty() ~= true then
						for _, pending_op in ipairs(client.pending_changes:viewAll()) do
							operation = ot.realignOperations(pending_op, operation)
						end
					end
				end
				if pcall(function(...)
					operation:execute(client.ignore_ticks)
				end) then
					print("char added")
				else
					for k, v in pairs(operation) do
						print(k .. ": " .. vim.inspect(v))
					end
					error("failed to add char")
				end

			else
				error("Unknown message " .. vim.inspect(decoded))
			end
		end
	end)
end

local function default_client_callbacks(client)
	return {
		on_connect = function()
			client_on_connect(client)
		end,

		on_text = function(wsdata)
			client_on_message_receive(client, wsdata)
		end,

		on_disconnect = function()
			vim.schedule(function()
				print("disconnected")
			end)
		end,
	}
end

return {
	default_client_callbacks = default_client_callbacks,
	client_attach_to_buffer = client_attach_to_buffer,
}