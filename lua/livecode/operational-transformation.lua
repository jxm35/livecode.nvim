local util = require("livecode.util")

local operation_metatable = {}
operation_metatable.__index = operation_metatable

local original_type = type 
type = function( obj )
    local otype = original_type( obj )
    if  otype == "table" and getmetatable( obj ) == operation_metatable then
        return "operation"
    end
    return otype
end

local function newOperation(opType, start_row, start_column, end_row, end_column, char)
    local op = {operationType = opType, start_row = start_row, start_column = start_column, end_row = end_row, end_column = end_column, character = char}
    return setmetatable(op, operation_metatable)
end
local function newOperationFromMessage(msg)
    local op = {operationType = msg.operationType, start_row = msg.start_row, start_column = msg.start_column, end_row =msg. end_row, end_column = msg.end_column, character = msg.character}
    return setmetatable(op, operation_metatable)
end

function operation_metatable:send(client)
    --assert(type(client) == "client", "ERROR: sending from invalid socket.")
    local msg = {
        util.MESSAGE_TYPE.EDIT,
        self
    }
    local encoded = vim.json.encode(msg)
    client:send_message(encoded)
end

function operation_metatable:execute()
    --vim.api.nvim_buf_set_text(0, 0, 28, 0, 32, {self.character})
    if self.operation == util.OPERATION_TYPE.INSERT then
        print("INSERT")
        vim.api.nvim_buf_set_text(0, self.start_row, self.start_column, self.start_row, self.start_column, {self.character})
    else
        print("DELETE")
        vim.api.nvim_buf_set_text(0, self.start_row, self.start_column, self.start_row+self.end_row, self.start_column+self.end_column, {self.character})
    end
end

local function transformInsertInsert(op1, op2)
    assert((type(op1)=="operation" and type(op2)=="operation"), "Error: invalid operation")
    if (op1.position < op2.position) or ((op1.position == op2.position) and order() == -1) then
        return newOperation(util.OPERATION_TYPE.INSERT, op1.position, op1.character) -- Tii(Ins[3, ‘a’], Ins[4, ‘b’]) = Ins[3, ‘a’]
    else
        return newOperation(util.OPERATION_TYPE.INSERT, op1.position+1, op1.character) -- Tii(Ins[3, ‘a’], Ins[1, ‘b’]) = Ins[4, ‘a’]
    end
end

local function transformInsertDelete(op1, op2)
    assert((type(op1)=="operation" and type(op2)=="operation"), "Error: invalid operation")
    if (op1.position <= op2.position) then
        return newOperation(util.OPERATION_TYPE.INSERT, op1.position, op1.character) -- Tid(Ins[3, ‘a’], Del[4]) = Ins[3, ‘a’]
    else
        return newOperation(util.OPERATION_TYPE.INSERT, op1.position-1, op1.character) -- Tid(Ins[3, ‘a’], Del[1]) = Ins[2, ‘a’]
    end
end

local function transformDeleteInsert(op1, op2)
    assert((type(op1)=="operation" and type(op2)=="operation"), "Error: invalid operation")
    if (op1.position < op2.position) then
        return newOperation(util.OPERATION_TYPE.DELETE, op1.position, op1.character)
    else
        return newOperation(util.OPERATION_TYPE.DELETE, op1.position+1, op1.character)
    end
end

local function transformDeleteDelete(op1, op2)
    assert((type(op1)=="operation" and type(op2)=="operation"), "Error: invalid operation")
    if (op1.position < op2.position) then
        return newOperation(util.OPERATION_TYPE.DELETE, op1.position, op1.character) -- Tdd(Del[3], Del[4]) = Del[3]
    elseif (op1.position > op2.position) then
        return newOperation(util.OPERATION_TYPE.DELETE, op1.position-1, op1.character) -- Tdd(Del[3], Del[1]) = Del[2]
    else
        return nil
    end
end

local function realignOperations(op1, op2)
    assert((type(op1)=="operation" and type(op2)=="operation"), "Error: invalid operation")
    if (op1.operationType == util.OPERATION_TYPE.INSERT) then
        if op2.operationType == util.OPERATION_TYPE.INSERT then
            return transformInsertInsert(op1, op2)
        else
            return transformInsertDelete(op1,op2)
        end
    else
        if op2.operationType == util.OPERATION_TYPE.INSERT then
            return transformDeleteInsert(op1,op2)
        else
            return transformDeleteDelete(op1,op2)
        end
    end
end

return {
    newOperation = newOperation,
    newOperationFromMessage = newOperationFromMessage,
    realignOperations = realignOperations
}