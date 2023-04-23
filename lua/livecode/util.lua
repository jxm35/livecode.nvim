-- File containing shared utility functions
--

local MESSAGE_TYPE = {

    CONNECT = 1,

    DISCONNECT = 2,

    WELCOME = 3,

    INFO = 4,

    GET_BUFFER = 5,

    BUFFER_CONTENT = 6,

    EDIT = 7,

    ACK = 8,

}

local OPERATION_TYPE = {
    INSERT = 1,

    DELETE = 2,

}

--local queue = {}
local queue_metatable = {}
queue_metatable.__index = queue_metatable

local original_type = type 
type = function( obj )
    local otype = original_type( obj )
    if  otype == "table" and getmetatable( obj ) == queue_metatable then
        return "queue"
    end
    return otype
end

function queue_metatable:new()
    return {first = 0, last = -1}
end

local function newQueue()
    local queue = {first = 0, last = -1}
    return setmetatable(queue, queue_metatable)
end

function queue_metatable:push(value)
    local last = self.last + 1
    self.last = last
    self[last] = value
end

function queue_metatable:dequeue()
    local first = self.first
    if first > self.last then error("list is empty") end
    local value = self[first]
    self[first] = nil
    self.first = first + 1
    return value
end

function queue_metatable:peek()
    local first = self.first
    if first > self.last then error("list is empty") end
    local value = self[first]
    return value
end

function queue_metatable:isEmpty()
    if self.first > self.last then
        return true
    end
    return false
end

return {
    MESSAGE_TYPE = MESSAGE_TYPE,
    OPERATION_TYPE = OPERATION_TYPE,
    newQueue = newQueue
}
