

    local util = require("livecode.util")

    local function server_on_message_receive(server, conn, wsdata, forward_to_other_users, forward_to_one_user)
        vim.schedule(function()
            local decoded = vim.json.decode(wsdata)
            if decoded then
                if decoded[1] == util.MESSAGE_TYPE.CONNECT then
                    local forward_msg = {
                        util.MESSAGE_TYPE.INFO,
                        decoded[2] .. " has joined.",
                    }
                    local encoded = vim.json.encode(forward_msg)
                    forward_to_other_users(encoded)
    
                    local isFirst = true
                    if #server.connections > 1 then
                        isFirst = false
                    end
                    local response_msg = {
                        util.MESSAGE_TYPE.WELCOME,
                        isFirst,
                    }
                    encoded = vim.json.encode(response_msg)
                    conn:send_message(encoded)
                elseif decoded[1] == util.MESSAGE_TYPE.GET_BUFFER then
                    decoded[2] = conn.id
                    local encoded = vim.json.encode(decoded)
                    forward_to_one_user(encoded)
                elseif decoded[1] == util.MESSAGE_TYPE.BUFFER_CONTENT then
                    decoded[6] = server.revision_number
                    local msg = vim.json.encode(decoded)
                    if decoded[2] == -1 then
                        forward_to_other_users(msg)
                    else
                        -- forward to the user in decoded[2]
                        for _, client in pairs(server.connections) do
                            if client.id == decoded[2] then
                                client:send_message(msg)
                                break
                            end
                        end
                    end
                elseif decoded[1] == util.MESSAGE_TYPE.INFO then
                    forward_to_other_users(wsdata)
                elseif decoded[1] == util.MESSAGE_TYPE.EDIT then
                    server.revision_number = server.revision_number + 1
                    decoded[4] = server.revision_number
                    local msg = vim.json.encode(decoded)
                    forward_to_other_users(msg)
                    local response_msg = {
                        util.MESSAGE_TYPE.ACK,
                        server.revision_number,
                    }
                    local encoded = vim.json.encode(response_msg)
                    conn:send_message(encoded)
                else
                    error("Unknown message " .. vim.inspect(decoded))
                end
            end
        end)
    end

    local function server_on_disconnect (server, conn, forward_to_other_users, forward_to_one_user)
        vim.schedule(function()
            server.connection_count = math.max(server.connection_count - 1, 0)
            if server.connection_count == 0 then
                server.initialised = false
            end
    
            local disconnect = {
                util.MESSAGE_TYPE.INFO,
                conn.id .. "has disconnected",
            }
            local encoded = vim.json.encode(disconnect)
            forward_to_other_users(encoded)
        end)
    end

    local function default_conn_callbacks (server, conn, forward_to_other_users, forward_to_one_user)
        return {
            on_text = function(wsdata)
                server_on_message_receive(server, conn, wsdata, forward_to_other_users, forward_to_one_user)
            end,

            on_disconnect = function()
                server_on_disconnect(server, conn, forward_to_other_users, forward_to_one_user)
            end,
        }
    end

    local function default_server_callbacks(server)
        return {
            on_connect = function(conn)
                server.connection_count = server.connection_count + 1
                server.forward_to_other_users = function (msg)
                    for id, client in pairs(server.connections) do
                        if id ~= conn.id then
                            client:send_message(msg)
                        end
                    end
                end
    
                server.forward_to_one_user = function (msg)
                    for id, client in pairs(server.connections) do
                        if id ~= conn.id then
                            client:send_message(msg)
                            break
                        end
                    end
                end
    
                conn:set_callbacks(default_conn_callbacks(server, conn))
            end,
        }
    end

    return {
        default_server_callbacks = default_server_callbacks,
        default_conn_callbacks = default_conn_callbacks
    }