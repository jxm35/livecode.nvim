local webSockClient = require("livecode.websocket.client")
local util = require("livecode.util")
local ot = require("livecode.operational-transformation")

local api_attach = {}
local agent = 0
local attached = false
local DETACH = false
local client

-- to make sure we don't send back the changes we just received
local ignore_ticks = {}

--Operational transaction necessities
local last_synced_revision = 0
local pending_changes = util.newQueue()
local sent_changes = nil
local document_state

local function StartClient(host, port)
	local host = host or "127.0.0.1"
	local port = port or 11359
    local username = "james"
    client = webSockClient { host=host, port=port }
    client:connect {
        on_connect = function ()
            local obj = {
                util.MESSAGE_TYPE.CONNECT,
                username,
            }
            local encoded = vim.json.encode(obj)
            client:send_message(encoded)


            for _, o in pairs(api_attach) do
                if o.on_connect then
                    o.on_connect()
                end
            end
            print("Attempting to connect...")
        end,

        on_text = function (wsdata)
            vim.schedule(function()
                local decoded = vim.json.decode(wsdata)
                if decoded then
                    if decoded[1] == util.MESSAGE_TYPE.INFO then
                        print("Recieved: " .. decoded[2])
                    elseif decoded[1] == util.MESSAGE_TYPE.WELCOME then
                        if decoded[2] == true then
                            print("I'm first")
                            local success = vim.api.nvim_buf_attach(0, false, {
                                on_bytes = function (_, buf, changedtick, start_row, start_column, byte_offset, old_end_row, old_end_column, old_byte_length, new_end_row, new_end_column, new_byte_length)
                                    if DETACH then
                                        return true
                                    end
                                    if ignore_ticks[changedtick] then
                                        print("skipping tick: " .. changedtick)
                                        ignore_ticks[changedtick] = nil
                                        return
                                    end

                                    print("doing tick: " .. changedtick)
                                    print(start_row..","..start_column..","..old_end_row..","..old_end_column)
                                    print(new_end_row..","..new_end_column)
                                    local newbytes = vim.api.nvim_buf_get_text(0, start_row, start_column, start_row+new_end_row, start_column+new_end_column, {})
                                    -- for i,v in ipairs(newbytes) do 
                                    --     print("char " .. i .. " '" .. newbytes[i] .. "'")
                                    -- end
                                    -- print("len " .. #newbytes)
                                    print("tick: " .. changedtick)
                                    local operationType = util.OPERATION_TYPE.INSERT
                                    if new_end_row < old_end_row then
                                        operationType = util.OPERATION_TYPE.DELETE
                                    elseif new_end_row == old_end_row and new_end_column < old_end_column then
                                            operationType = util.OPERATION_TYPE.DELETE
                                    end
                                    local operation = ot.newOperation(operationType, start_row, start_column, old_end_row, old_end_column, newbytes)
                                    if sent_changes == nil then
                                        operation:send(client)
                                        sent_changes = operation
                                        print("sent operation")
                                    else
                                        pending_changes:push(operation)
                                        print("pushed op to pending")
                                    end
                                end
                            })
                        else
                            local req = {
                                util.MESSAGE_TYPE.GET_BUFFER,
                            }
                            local encoded = vim.json.encode(req)
                            client:send_message(encoded)
                        end
                    elseif decoded[1] == util.MESSAGE_TYPE.GET_BUFFER then
                        print("buffer requested.")
                        local fullname = vim.api.nvim_buf_get_name(0)
                        local cwdname = vim.api.nvim_call_function("fnamemodify",
                            { fullname, ":." }) -- filepath relative to current working directory
                        local bufname = cwdname
                        --if bufname == fullname then

                            bufname = vim.api.nvim_call_function("fnamemodify",
                            { fullname, ":t" }) -- split off everything before the last '/'
                        --                      end
                        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true) --current buf, start line, last line, 
                        local rem = {agent, bufname}

                        local obj = {
                            util.MESSAGE_TYPE.BUFFER_CONTENT,
                            bufname,
                            rem,
                            "pidslist",
                            lines
                        }
                        local encoded = vim.json.encode(obj)
                        client:send_message(encoded)

                    elseif decoded[1] == util.MESSAGE_TYPE.BUFFER_CONTENT then
                        print("loading new buffer")
                        local _, bufname, bufid, pidslist, content = unpack(decoded)
                        local ag, bufid = unpack(bufid)
                        local buf = vim.api.nvim_create_buf(true, false)
                        vim.api.nvim_win_set_buf(0, buf)
                        vim.api.nvim_buf_set_name(buf, bufname)
                        vim.api.nvim_buf_set_lines(buf, 0, -1, true, content)
                        vim.api.nvim_exec("edit!", false)

                        --Attach to buffer

                        local success = vim.api.nvim_buf_attach(0, false, {
                            on_bytes = function (_, buf, changedtick, start_row, start_column, byte_offset, old_end_row, old_end_column, old_byte_length, new_end_row, new_end_column, new_byte_length)
                                if DETACH then
                                    return true
                                end
                                if ignore_ticks[changedtick] then
                                    ignore_ticks[changedtick] = nil
                                    return
                                end
                                print(start_row..","..start_column..","..old_end_row..","..old_end_column)
                                print(new_end_row..","..new_end_column)
                                local newbytes = vim.api.nvim_buf_get_text(0, start_row, start_column, start_row+new_end_row, start_column+new_end_column, {})
                                -- for i,v in ipairs(newbytes) do 
                                --     print("char " .. i .. " '" .. newbytes[i] .. "'")
                                -- end
                                -- print("len " .. #newbytes)
                                print("tick: " .. changedtick)
                                local operationType = util.OPERATION_TYPE.INSERT
                                if new_end_row < old_end_row then
                                    operationType = util.OPERATION_TYPE.DELETE
                                elseif new_end_row == old_end_row and new_end_column < old_end_column then
                                        operationType = util.OPERATION_TYPE.DELETE
                                end
                                local operation = ot.newOperation(operationType, start_row, start_column, old_end_row, old_end_column, newbytes)
                                if sent_changes == nil then
                                    operation:send(client)
                                    sent_changes = operation
                                    print("sent operation")
                                else
                                    pending_changes:push(operation)
                                    print("pushed op to pending")
                                end
                            end
                        })

                    elseif decoded[1]== util.MESSAGE_TYPE.ACK then
                        --validate they are the same,
                        print("ack Recieved")
                        sent_changes = nil
                        if pending_changes:isEmpty() == false then
                            local operation = pending_changes:dequeue()
                            operation:send(client)
                            sent_changes = operation
                            print("new operation sent")
                        end
                    elseif decoded[1]== util.MESSAGE_TYPE.EDIT then
                        local operation = ot.newOperationFromMessage(decoded[2])
                        local next_tick = vim.api.nvim_buf_get_changedtick(0)
                        ignore_ticks[next_tick] = true
                        print("ignoring tick: " .. next_tick)
                        operation:execute()
                        print("char added")
                    else
                        error("Unknown message " .. vim.inspect(decoded))
                    end
                end
            end)
        end,
        on_disconnect = function ()
            vim.schedule(function()
                print("disconnected")
            end)
        end
    }
end

local function Start(host, port)
    local buf = vim.api.nvim_get_current_buf()
	StartClient(host, port)
end

local function Join(host, port)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, buf)
    StartClient(host, port)
end

local function Stop()
	client:disconnect()
	client = nil
end

return {
    start = Start,
    join = Join,
    stop = Stop
}
