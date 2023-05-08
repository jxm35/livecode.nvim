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
	if opType ~= OPERATION_TYPE.INSERT and opType ~= OPERATION_TYPE.DELETE then
		error("invalid operation type")
	end
	if type(start_row) ~= "number" then
		error("invalid start_row")
	elseif type(start_column) ~= "number" then
		error("invalid start_column")
	elseif type(end_row) ~= "number" then
		error("invalid end_row")
	elseif type(end_column) ~= "number" then
		error("invalid end_column")
	elseif type(char) ~= "table" or type(char[1]) ~= "string" then
		error("invalid character")
	end

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

local function newOperationFromMessage(msg)
	if msg.operationType ~= OPERATION_TYPE.INSERT and msg.operationType ~= OPERATION_TYPE.DELETE then
		error("invalid operation type")
	end
	if type(msg.start_row) ~= "number" then
		error("invalid start_row")
	elseif type(msg.start_column) ~= "number" then
		error("invalid start_column")
	elseif type(msg.end_row) ~= "number" then
		error("invalid end_row")
	elseif type(msg.end_column) ~= "number" then
		error("invalid end_column")
	elseif type(msg.character) ~= "table" or type(msg.character[1]) ~= "string" then
		error("invalid character")
	end

	local op = {
		operationType = msg.operationType,
		start_row = msg.start_row,
		start_column = msg.start_column,
		end_row = msg.end_row,
		end_column = msg.end_column,
		character = msg.character,
	}
	return setmetatable(op, operation_metatable)
end

function operation_metatable:send(conn)
	--assert(type(client) == "client", "ERROR: sending from invalid socket.")
	local msg = {
		util.MESSAGE_TYPE.EDIT,
		self,
	}
	local encoded = vim.json.encode(msg)
	conn:send_message(encoded)
end

function operation_metatable:execute(ignore_table)
	--vim.api.nvim_buf_set_text(0, 0, 28, 0, 32, {self.character})
	print("op" .. self.operationType .. " " .. OPERATION_TYPE.INSERT)
	if self.operationType == OPERATION_TYPE.INSERT then
		print("INSERT")
		local current_row = self.start_row
		local action_row = current_row
		local next_tick = vim.api.nvim_buf_get_changedtick(0)
		ignore_table[next_tick] = true
		vim.api.nvim_buf_set_text(
			0,
			self.start_row,
			self.start_column,
			current_row,
			self.start_column,
			self.character
		)
		-- fix glitches when pressing the enter key
		if #self.character == 2 and self.character[1] == "" then
			local col = math.min(#self.character[2], self.start_column)
			next_tick = vim.api.nvim_buf_get_changedtick(0)
			ignore_table[next_tick] = true
			vim.api.nvim_buf_set_text(
				0,
				self.start_row+1,
				0,
				self.start_row+1,
				col,
				{}
			)
		end
	else
		print("DELETE")
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

local function transformInsertInsert(local_operation, incoming_operation)
	assert(
		(type(local_operation) == "operation" and type(incoming_operation) == "operation"),
		"Error: invalid operation"
	)
	if
		(local_operation.start_column < incoming_operation.start_column)
		or ((local_operation.start_column == incoming_operation.start_column) and order() == -1)
	then
		return newOperation(
			OPERATION_TYPE.INSERT,
			incoming_operation.start_row,
			incoming_operation.start_column + #local_operation.character[1],
			incoming_operation.end_row,
			incoming_operation.end_column + #local_operation.character[1],
			incoming_operation.character
		) -- Tii(Ins[3, ‘a’], Ins[4, ‘b’]) = Ins[3, ‘a’]
	else
		return incoming_operation -- Tii(Ins[3, ‘a’], Ins[1, ‘b’]) = Ins[4, ‘a’]
	end
end

local function transformInsertDelete(local_operation, incoming_operation)
	assert(
		(type(local_operation) == "operation" and type(incoming_operation) == "operation"),
		"Error: invalid operation"
	)
	if local_operation.start_column <= incoming_operation.start_column then
		return newOperation(
			OPERATION_TYPE.DELETE,
			incoming_operation.start_row,
			incoming_operation.start_column + #local_operation.character[1],
			incoming_operation.end_row,
			incoming_operation.end_column + #local_operation.character[1],
			incoming_operation.character
		) -- Tid(Ins[3, ‘a’], Del[4]) = Ins[3, ‘a’]
	else
		return incoming_operation -- Tid(Ins[3, ‘a’], Del[1]) = Ins[2, ‘a’]
	end
end

local function transformDeleteInsert(local_operation, incoming_operation)
	assert(
		(type(local_operation) == "operation" and type(incoming_operation) == "operation"),
		"Error: invalid operation"
	)
	if local_operation.start_column < incoming_operation.start_column then
		return newOperation(
			OPERATION_TYPE.INSERT,
			incoming_operation.start_row,
			incoming_operation.start_column - #local_operation.character[1],
			incoming_operation.end_row,
			incoming_operation.end_column - #local_operation.character[1],
			incoming_operation.character
		)
	else
		return incoming_operation
	end
end

local function transformDeleteDelete(local_operation, incoming_operation)
	assert(
		(type(local_operation) == "operation" and type(incoming_operation) == "operation"),
		"Error: invalid operation"
	)
	if local_operation.start_column < incoming_operation.start_column then
		return newOperation(
			OPERATION_TYPE.DELETE,
			incoming_operation.start_row,
			incoming_operation.start_column - #local_operation.character[1],
			incoming_operation.end_row,
			incoming_operation.end_column - #local_operation.character[1],
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
	if local_operation.start_row ~= incoming_operation.start_row then
		return incoming_operation
	end
	if local_operation.operationType == OPERATION_TYPE.INSERT then
		if incoming_operation.operationType == OPERATION_TYPE.INSERT then
			return transformInsertInsert(local_operation, incoming_operation)
		else
			return transformInsertDelete(local_operation, incoming_operation)
		end
	else
		if incoming_operation.operationType == OPERATION_TYPE.INSERT then
			return transformDeleteInsert(local_operation, incoming_operation)
		else
			return transformDeleteDelete(local_operation, incoming_operation)
		end
	end
end

return {
	newOperation = newOperation,
	newOperationFromMessage = newOperationFromMessage,
	realignOperations = realignOperations,
	OPERATION_TYPE = OPERATION_TYPE,
}
