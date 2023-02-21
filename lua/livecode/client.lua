local webSockClient = require("livecode.websocket.client")
local util = require("livecode.util")

local api_attach = {}
local agent = 0
local attached = false
local DETACH = false
local client

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
            local decoded = vim.json.decode(wsdata)
            if decoded then
                if decoded[1] == util.MESSAGE_TYPE.INFO then
                    print("Recieved: " .. decoded[2])
                end

                if decoded[1] == util.MESSAGE_TYPE.WELCOME then
                    if decoded[2] == true then
                        print("I'm first")
                    else
                        local req = {
                            util.MESSAGE_TYPE.GET_BUFFER,
                        }
                        local encoded = vim.json.encode(req)
                        client:send_message(encoded)
                    end
                end

                if decoded[1] == util.MESSAGE_TYPE.GET_BUFFER then
                    print("buffer requested.")
                    local fullname = vim.api.nvim_buf_get_name(0)
                    local cwdname = vim.api.nvim_call_function("fnamemodify",
                        { fullname, ":." }) -- filepath relative to current working directory
                    local bufname = cwdname
                    print(bufname .. "   " .. fullname)
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

                    end

                    if decoded[1] == util.MESSAGE_TYPE.BUFFER_CONTENT then
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
                                print(start_row..","..start_column..","..old_end_row..","..old_end_column)
                                print("a - " .. vim.inspect(bytes))
                                local newbytes = vim.api.nvim_buf_get_text(0, start_row, start_column, start_row+new_end_row, start_column+new_end_column, {})
                                print("b - " .. vim.inspect(newbytes))
                                local operation = util.OPERATION_Type.INSERT
                                if new_end_row == 0 and new_end_column == 0 then
                                    operation = util.OPERATION_Type.INSERT
                                end
                                local msg = {
                                    util.MESSAGE_TYPE.EDIT,
                                    operation,
                                    {}
                                }

                                
                            end
                        })


                        -- if vim.api.nvim_buf_call then
                        --     vim.api.nvim_buf_call(buf, function()
                        --         vim.api.nvim_command("doautocmd BufRead " .. vim.api.nvim_buf_get_name(buf))
                        --     end)
                        -- end

                        -- if not attached then
                        --     local attach_success = vim.api.nvim_buf_attach(buf, false, {
                        --         on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, bytecount)
                        --             print("line change detected!")
                        --         end,
                        --         on_detach = function(_, buf)
                        --             attached = false
                        --         end

                        --     })

                        --     if attach_success then
                        --         attached = true
                        --     end

                        -- else -- if not attached
                        --     detach[buf] = nil

                        -- end

                    end
            end
            
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
