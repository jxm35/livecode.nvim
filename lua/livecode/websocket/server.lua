local bit = require("bit")
local websocket_util = require("livecode.websocket.util")

local connections = {}
local conn_id = 1
local split_length = 8192

local connection_impl = {}
function connection_impl:attach(callbacks)
	self.callbacks = callbacks
end
function connection_impl:send_message(str)
    print("sending:"..str)
    local mask = {}
    for i=1,4 do
        table.insert(mask, math.random(0, 255))
    end

    local masked = maskText(str, mask)


    local remain = #masked
    local sent = 0
    while remain > 0 do
        local send = math.min(split_length, remain) -- max size before fragment
        remain = remain - send
        local fin
        if remain == 0 then fin = 0x80
        else fin = 0 end

        local opcode
        if sent == 0 then opcode = 1
        else opcode = 0 end


        local frame = {
            fin+opcode, 0x80
        } -- 1, 128 to start with

        -- write the length of the frame
        if send <= 125 then
            frame[2] = frame[2] + send
        elseif send < math.pow(2, 16) then -- 65,536
            frame[2] = frame[2] + 126 -- becomes 254
            local b1 = bit.rshift(send, 8) -- stays as 0
            local b2 = bit.band(send, 0xFF) -- 0
            table.insert(frame, b1)
            table.insert(frame, b2)
        else
            frame[2] = frame[2] + 127 -- becomes 255
            for i=0,7 do
                local b = bit.band(bit.rshift(send, (7-i)*8), 0xFF)
                table.insert(frame, b)
            end
        end


        for i=1,4 do
            table.insert(frame, mask[i])
        end

        for i=sent+1,sent+1+(send-1) do
            table.insert(frame, masked[i])
        end

        local s = convert_bytes_to_string(frame)

        connections[self.id].sock:write(s)
        print("written to: " .. self.id)

        sent = sent + send
    end
end

function Run_server(opt)
    local host = opt.host or '127.0.0.1'
    local port = opt.port or 11359
    local server = vim.loop.new_tcp()
    server:bind(host,port)
    print('TCP echo-server listening on port: '..server:getsockname().port)
    local websocket_impl = {}
    websocket_impl.connections = connections

    function websocket_impl:listen(callbacks)
        local ret, err = server:listen(128, function (err)
            local sock = vim.loop.new_tcp()
            server:accept(sock)
            local conn
            local http_data = ""
            local chunk_buffer = ""
            -- client_reader_coroutine
            local function getdata(amount)
                while string.len(chunk_buffer) < amount do
                    coroutine.yield()
                end
                local retrieved = string.sub(chunk_buffer, 1, amount)
                chunk_buffer = string.sub(chunk_buffer, amount+1)
                return retrieved
            end
            local read_coroutine = coroutine.create(function()
                while true do
                    local wsdata = ""
                    local fin

                    --read_header_two_bytes_first
                    local rec = getdata(2)
                    local b1 = string.byte(string.sub(rec,1,1))
                    local b2 = string.byte(string.sub(rec,2,2))
                    local opcode = bit.band(b1, 0xF)
                    fin = bit.rshift(b1, 7)
                    --read_payload_length
                    local paylen = bit.band(b2, 0x7F)
                    if paylen == 126 then -- 16 bits length
                        local rec = getdata(2)
                        local b3 = string.byte(string.sub(rec,1,1))
                        local b4 = string.byte(string.sub(rec,2,2))
                        paylen = bit.lshift(b3, 8) + b4
                    elseif paylen == 127 then
                        paylen = 0
                        local rec = getdata(8)
                        for i=1,8 do -- 64 bits length
                            paylen = bit.lshift(paylen, 8) 
                            paylen = paylen + string.byte(string.sub(rec,i,i))
                        end
                    end
                    --read_mask
                    local mask = {}
                    local rec = getdata(4)
                    for i=1,4 do
                        table.insert(mask, string.byte(string.sub(rec, i, i)))
                    end
                    --read_payload
                    local data = getdata(paylen)
                    --unmask_data
                    local unmasked = unmask_text(data, mask)
                    data = convert_bytes_to_string(unmasked)

                    wsdata = data

                    while fin == 0 do
                        --read_header_two_bytes_fragmented
                        local rec = getdata(2)
                        local b1 = string.byte(string.sub(rec,1,1)) -- will be 
                        local b2 = string.byte(string.sub(rec,2,2))
                        fin = bit.rshift(b1, 7) -- becomes 1 if this is the last frame
                        --read_payload_length
                        local paylen = bit.band(b2, 0x7F) -- 127, 
                        if paylen == 126 then -- 16 bits length
                            local rec = getdata(2)
                            local b3 = string.byte(string.sub(rec,1,1))
                            local b4 = string.byte(string.sub(rec,2,2))
                            paylen = bit.lshift(b3, 8) + b4
                        elseif paylen == 127 then
                            paylen = 0
                            local rec = getdata(8)
                            for i=1,8 do -- 64 bits length
                                paylen = bit.lshift(paylen, 8) 
                                paylen = paylen + string.byte(string.sub(rec,i,i))
                            end
                        end
                        --read_mask
                        local mask = {}
                        local rec = getdata(4)
                        for i=1,4 do
                            table.insert(mask, string.byte(string.sub(rec, i, i)))
                        end
                        --read_payload
                        local data = getdata(paylen)
                        --unmask_data
                        local unmasked = unmask_text(data, mask)
                        data = convert_bytes_to_string(unmasked)

                        wsdata = wsdata .. data
                    end

                    if opcode == 0x1 then
                        if conn and conn.callbacks.on_text then
                            conn.callbacks.on_text(wsdata)
                        end
                    end
                    if opcode == 0x8 then -- CLOSE
                        --close_client_callbacks
                        if conn and conn.callbacks.on_disconnect then
                            conn.callbacks.on_disconnect()
                        end
                        --remove_client
                        connections[conn.id] = nil
                        connections.sock:close()
                        break
                    end
                end
            end)
            -- call_callbacks_connected 
            if callbacks.on_connect then
                conn = setmetatable(
                { id = conn_id, sock = sock },
                { __index = connection_impl })
                connections[conn_id] = conn
                conn_id = conn_id + 1
                callbacks.on_connect(conn)
            end
            -- register_socket_read_callback
            sock:read_start(function(err, chunk)
                if chunk then
                    --read_message_tcp
                    chunk_buffer = chunk_buffer .. chunk
                    coroutine.resume(read_coroutine)
                else
                    -- close_client_callbacks
                    if conn and conn.callbacks.on_disconnect then
                        conn.callbacks.on_disconnect()
                    end
                    -- remove_client
                    connections[conn.id] = nil
                    sock:shutdown()
                    sock:close()
                end
            end)
        end)
        if not ret then
            error(err)
        end
    end
    function websocket_impl:close()
        for _, conn in pairs(connections) do
            if conn and conn.callbacks.on_disconnect then
                conn.callbacks.on_disconnect()
            end

            conn.sock:shutdown()
            conn.sock:close()
        end

        connections = {}

        if server then
            server:close()
            server = nil
        end
    end
    return setmetatable({}, { __index = websocket_impl})
end

return Run_server
