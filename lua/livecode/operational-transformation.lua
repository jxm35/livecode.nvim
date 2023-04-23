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

function operation_metatable:execute(ignore_table)
    --vim.api.nvim_buf_set_text(0, 0, 28, 0, 32, {self.character})
    print("op" .. self.operationType .. " " .. util.OPERATION_TYPE.INSERT)
    if self.operationType == util.OPERATION_TYPE.INSERT then
        print("INSERT")
        local current_row = self.start_row
        local action_row = current_row
        local next_tick = vim.api.nvim_buf_get_changedtick(0)
        ignore_table[next_tick] = true
        vim.api.nvim_buf_set_text(0, self.start_row, self.start_column, current_row, self.start_column, {self.character[1]})
        current_row = current_row + 1
        for index, value in ipairs(self.character) do
            print("value: '" .. value .. "'")
            if index > 1 then
                -- pasted text gets put a line too high
                if value == "" and self.start_column == 0 then
                    action_row = current_row -1
                else
                    action_row = current_row
                end
                next_tick = vim.api.nvim_buf_get_changedtick(0)
                ignore_table[next_tick] = true
                vim.api.nvim_buf_set_lines(0, action_row, action_row, false, {value})
                current_row = current_row + 1
            end
        end

    else
        print("DELETE")
        local action_column = self.start_column+self.end_column
        local sr = self.start_row
        local sc = self.start_column
        local er = self.start_row+self.end_row
        if self.end_row>0 and self.end_column>0 then
            action_column = self.end_column
        end
        if self.start_column>0 and self.end_row==1 and self.end_column == 0 then
            sr = self.start_row+1
            sc = 0
            er = sr+1
            action_column=0
        end
        print(sr .. " " .. sc .. " " .. er .. " " .. action_column)
        local next_tick = vim.api.nvim_buf_get_changedtick(0)
        ignore_table[next_tick] = true
        vim.api.nvim_buf_set_text(0, sr, sc, er, action_column, {self.character[1]})
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