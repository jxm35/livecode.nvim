local util = require("livecode.util")

local OPERATION_TYPE = {
	INSERT = 1,

	DELETE = 2,
}

local operation_metatable = {}
operation_metatable.__index = operation_metatable

local original_type = type
type = function(obj)
	local otype = original_type(obj)
	if otype == "table" and getmetatable(obj) == operation_metatable then
		return "operation"
	end
	return otype
end

local function newOperation(opType, start_row, start_column, end_row, end_column, char)
	assert(
		(opType == OPERATION_TYPE.INSERT or opType == OPERATION_TYPE.DELETE),
		"invalid operation type"
	)
	assert(type(start_row) == "number")
	assert(type(start_column) == "number")
	assert(type(end_row) == "number")
	assert(type(end_column) == "number")
	assert(type(char) == "table")

	local op = {
		operationType = opType,
		start_row = start_row,
		start_column = start_column,
		end_row = end_row,
		end_column = end_column,
		character = char,
	}
	return setmetatable(op, operation_metatable)
end

local function newOperationExtended(
	opType,
	start_row,
	start_column,
	end_row,
	end_column,
	new_end_row,
	new_end_column,
	char
)
	assert(
		(opType == OPERATION_TYPE.INSERT or opType == OPERATION_TYPE.DELETE),
		"invalid operation type"
	)
	assert(type(start_row) == "number")
	assert(type(start_column) == "number")
	assert(type(end_row) == "number")
	assert(type(end_column) == "number")
	assert(type(new_end_row) == "number")
	assert(type(new_end_column) == "number")
	assert(type(char) == "table")

	local op = {
		operationType = opType,
		start_row = start_row,
		start_column = start_column,
		end_row = end_row,
		end_column = end_column,
		new_end_row = new_end_row,
		new_end_column = new_end_column,
		character = char,
	}
	return setmetatable(op, operation_metatable)
end

local function newOperationFromMessage(msg)
	assert(
		(msg.operationType == OPERATION_TYPE.INSERT or msg.operationType == OPERATION_TYPE.DELETE),
		"invalid operation type"
	)
	assert(type(msg.start_row) == "number")
	assert(type(msg.start_column) == "number")
	assert(type(msg.end_row) == "number")
	assert(type(msg.end_column) == "number")
	assert(type(msg.new_end_row) == "number")
	assert(type(msg.new_end_column) == "number")
	assert(type(msg.character) == "table")

	local op = {
		operationType = msg.operationType,
		start_row = msg.start_row,
		start_column = msg.start_column,
		end_row = msg.end_row,
		end_column = msg.end_column,
		new_end_row = msg.new_end_row,
		new_end_column = msg.new_end_column,
		character = msg.character,
	}
	return setmetatable(op, operation_metatable)
end

function operation_metatable:send(conn, lsr)
	--assert(type(client) == "client", "ERROR: sending from invalid socket.")
	assert(type(conn) == "connection")
	assert(type(lsr)=="number")
	
	local msg = {
		util.MESSAGE_TYPE.EDIT,
		self,
		lsr,
	}
	local encoded = vim.json.encode(msg)
	conn:send_message(encoded)
end

function operation_metatable:execute(ignore_table)
	assert( type(ignore_table) == "table", "Error: invalid ignore_table provided")
	--vim.api.nvim_buf_set_text(0, 0, 28, 0, 32, {self.character})
	print("op" .. self.operationType .. " " .. OPERATION_TYPE.INSERT)
	if self.operationType == OPERATION_TYPE.INSERT then
		print("INSERT")
		local current_row = self.start_row
		local action_row = current_row
		local next_tick = vim.api.nvim_buf_get_changedtick(0)
		ignore_table[next_tick] = true
		vim.api.nvim_buf_set_text(0, self.start_row, self.start_column, current_row, self.start_column, self.character)
		-- fix glitches when pressing the enter key
		if #self.character == 2 and self.character[1] == "" then
			local col = math.min(#self.character[2], self.start_column)
			next_tick = vim.api.nvim_buf_get_changedtick(0)
			ignore_table[next_tick] = true
			vim.api.nvim_buf_set_text(0, self.start_row + 1, 0, self.start_row + 1, col, {})
		end
	else
		print("DELETE")
		print(vim.inspect(self.character))
		local action_column = self.start_column + self.end_column
		local sr = self.start_row
		local sc = self.start_column
		local er = self.start_row + self.end_row
		if self.end_row > 0 and self.end_column > 0 then
			action_column = self.end_column
		end
		-- for deleting the first character of the line
		if self.start_column > 0 and self.end_row == 1 and self.end_column == 0 then
			action_column = 0
		end
		print(sr .. " " .. sc .. " " .. er .. " " .. action_column)
		local next_tick = vim.api.nvim_buf_get_changedtick(0)
		ignore_table[next_tick] = true
		vim.api.nvim_buf_set_text(0, sr, sc, er, action_column, { self.character[1] })
	end
end

local function transformInsertInsert(local_operation, incoming_operation, local_row_num, incoming_row_num)
	assert(
		(type(local_operation) == "operation" and type(incoming_operation) == "operation"),
		"Error: invalid operation"
	)
	assert((type(local_row_num) == "number" and type(incoming_row_num) == "number"), "Error: invalid row number types")
	print("-----------------change-char:" .. incoming_operation.character[1])
	if
		local_operation.start_column <= incoming_operation.start_column
		--		or ((local_operation.start_column == incoming_operation.start_column) and order() == -1)
	then
		local new_start_col = incoming_operation.start_column

		if incoming_row_num == 1 then -- we shouldn't change the start col if the text is inserted on another row
			new_start_col = incoming_operation.start_column + #local_operation.character[local_row_num]
		end

		return newOperationExtended(
			OPERATION_TYPE.INSERT,
			incoming_operation.start_row,
			new_start_col,
			incoming_operation.end_row,
			incoming_operation.end_column,
			incoming_operation.new_end_row,
			incoming_operation.new_end_column,
			incoming_operation.character
		) -- Tii(Ins[3, ‘a’], Ins[4, ‘b’]) = Ins[3, ‘a’]
	else
		return incoming_operation -- Tii(Ins[3, ‘a’], Ins[1, ‘b’]) = Ins[4, ‘a’]
	end
end

local function transformInsertDelete(local_operation, incoming_operation, local_row_num, incoming_row_num)
	assert(
		(type(local_operation) == "operation" and type(incoming_operation) == "operation"),
		"Error: invalid operation"
	)
	assert((type(local_row_num) == "number" and type(incoming_row_num) == "number"), "Error: invalid row number types")
	if local_operation.start_column <= incoming_operation.start_column then
		local new_start_col = incoming_operation.start_column

		if incoming_row_num == 1 then
			new_start_col = incoming_operation.start_column + #local_operation.character[local_row_num]
		end

		return newOperationExtended(
			OPERATION_TYPE.DELETE,
			incoming_operation.start_row,
			new_start_col,
			incoming_operation.end_row,
			incoming_operation.end_column,
			incoming_operation.new_end_row,
			incoming_operation.new_end_column,
			incoming_operation.character
		) -- Tid(Ins[3, ‘a’], Del[4]) = Ins[3, ‘a’]
	else
		return incoming_operation -- Tid(Ins[3, ‘a’], Del[1]) = Ins[2, ‘a’]
	end
end

local function transformDeleteInsert(local_operation, incoming_operation, local_row_num, incoming_row_num)
	assert(
		(type(local_operation) == "operation" and type(incoming_operation) == "operation"),
		"Error: invalid operation"
	)
	assert((type(local_row_num) == "number" and type(incoming_row_num) == "number"), "Error: invalid row number types")
	if local_operation.start_column < incoming_operation.start_column then
		local new_start_col = incoming_operation.start_column

		if incoming_row_num == 1 then
			new_start_col = incoming_operation.start_column - local_operation.end_column
		end

		return newOperationExtended(
			OPERATION_TYPE.INSERT,
			incoming_operation.start_row,
			new_start_col,
			incoming_operation.end_row,
			incoming_operation.end_column,
			incoming_operation.new_end_row,
			incoming_operation.new_end_column,
			incoming_operation.character
		)
	else
		return incoming_operation
	end
end

local function transformDeleteDelete(local_operation, incoming_operation, local_row_num, incoming_row_num)
	print("transformDeleteDelete")
	assert(
		(type(local_operation) == "operation" and type(incoming_operation) == "operation"),
		"Error: invalid operation"
	)
	assert((type(local_row_num) == "number" and type(incoming_row_num) == "number"), "Error: invalid row number types")
	if local_operation.start_column < incoming_operation.start_column then
		local new_start_col = incoming_operation.start_column

		if incoming_row_num == 1 then
			new_start_col = incoming_operation.start_column - local_operation.end_column
		end

		return newOperationExtended(
			OPERATION_TYPE.DELETE,
			incoming_operation.start_row,
			new_start_col,
			incoming_operation.end_row,
			incoming_operation.end_column,
			incoming_operation.new_end_row,
			incoming_operation.new_end_column,
			incoming_operation.character
		) -- Tdd(Del[3], Del[4]) = Del[3]
	elseif local_operation.start_column > incoming_operation.start_column then
		return incoming_operation -- Tdd(Del[3], Del[1]) = Del[2]
	else
		error("deleted same char twice")
		return newOperation()
	end
end

local function realignOperations(local_operation, incoming_operation)
	assert(
		(type(local_operation) == "operation" and type(incoming_operation) == "operation"),
		"Error: invalid operation"
	)
	print("----------------------checking-char:" .. incoming_operation.character[1])
	print("against: " .. local_operation.character[1], ", " .. local_operation.start_row)
	print("before")
	for k, v in pairs(incoming_operation) do
		print(k .. ": " .. vim.inspect(v))
	end

	-- handle changes that affect which line we have changed
	local line_diff = local_operation.new_end_row - local_operation.end_row
	if incoming_operation.start_row > local_operation.start_row then
		print("line diff: " .. line_diff)
		incoming_operation.start_row = incoming_operation.start_row + line_diff
		-- incoming_operation.end_row = incoming_operation.end_row + line_diff
	end

	-- check if any changes are on the same row in each document
	local local_rows_in_common = {}
	local incoming_rows_in_common = {}
	local local_row_num = 1
	local incoming_row_num = 1
	for i = local_operation.start_row, local_operation.start_row + local_operation.new_end_row, 1 do
		for j = incoming_operation.start_row, incoming_operation.start_row + incoming_operation.new_end_row do
			if i == j then
				table.insert(local_rows_in_common, local_row_num)
				table.insert(incoming_rows_in_common, incoming_row_num)
			end
			incoming_row_num = incoming_row_num + 1
		end
		local_row_num = local_row_num + 1
	end

	-- handle changes on the same line
	for index, row_num in ipairs(local_rows_in_common) do
		if local_operation.operationType == OPERATION_TYPE.INSERT then
			if incoming_operation.operationType == OPERATION_TYPE.INSERT then
				incoming_operation =
					transformInsertInsert(local_operation, incoming_operation, row_num, incoming_rows_in_common[index])
			else
				incoming_operation =
					transformInsertDelete(local_operation, incoming_operation, row_num, incoming_rows_in_common[index])
			end
		else
			if incoming_operation.operationType == OPERATION_TYPE.INSERT then
				incoming_operation =
					transformDeleteInsert(local_operation, incoming_operation, row_num, incoming_rows_in_common[index])
			else
				incoming_operation =
					transformDeleteDelete(local_operation, incoming_operation, row_num, incoming_rows_in_common[index])
			end
		end
	end

	print("after")
	for k, v in pairs(incoming_operation) do
		print(k .. ": " .. vim.inspect(v))
	end

	return incoming_operation
end

return {
	newOperation = newOperation,
	newOperationExtended = newOperationExtended,
	newOperationFromMessage = newOperationFromMessage,
	realignOperations = realignOperations,
	OPERATION_TYPE = OPERATION_TYPE,
}
