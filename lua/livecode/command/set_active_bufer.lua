local ot = require("livecode.operational-transformation")
local util = require("livecode.util")

local function SetActiveBuffer()
    if Client == nil then
        error("nil Client - please join a session before changing the buffer")
    end
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
            if Client.DETACH then
                return true
            end
            if Client.ignore_ticks[changedtick] then
                Client.ignore_ticks[changedtick] = nil
                return
            end
            print(start_row .. "," .. start_column .. "," .. old_end_row .. "," .. old_end_column)
            print(new_end_row .. "," .. new_end_column)
            local newbytes = vim.api.nvim_buf_get_text(
                0,
                start_row,
                start_column,
                start_row + new_end_row,
                start_column + new_end_column,
                {}
            )
            print("tick: " .. changedtick)
            local operationType = ot.OPERATION_TYPE.INSERT
            if new_end_row < old_end_row then
                operationType = ot.OPERATION_TYPE.DELETE
            elseif new_end_row == old_end_row and new_end_column < old_end_column then
                operationType = ot.OPERATION_TYPE.DELETE
            end
            local operation = ot.newOperation(
                operationType,
                start_row,
                start_column,
                old_end_row,
                old_end_column,
                newbytes
            )
            if Client.sent_changes == nil then
                operation:send(Client.active_conn)
                Client.sent_changes = operation
                print("sent operation")
            else
                Client.pending_changes:push(operation)
                print("pushed op to pending")
            end
        end,
    })

    local fullname = vim.api.nvim_buf_get_name(0)
    local cwdname = vim.api.nvim_call_function("fnamemodify", { fullname, ":." }) -- filepath relative to current working directory
    local bufname = cwdname
    --if bufname == fullname then

    bufname = vim.api.nvim_call_function("fnamemodify", { fullname, ":t" }) -- split off everything before the last '/'
    --                      end
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true) --current buf, start line, last line,

    local obj = {
        util.MESSAGE_TYPE.BUFFER_CONTENT,
        -1,
        bufname,
        "pidslist",
        lines,
    }
    local encoded = vim.json.encode(obj)
    Client.active_conn:send_message(encoded)
end

return {
    SetActiveBuffer = SetActiveBuffer
}