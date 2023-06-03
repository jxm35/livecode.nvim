local tu = require("tests.test_utils")
local function getBufLines()
	local result = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
	return result
end

describe("check edit messages (insert):", function()
	local input = [[hello world]]
	local expected = [[hello world!]]
	local testModule = require("livecode")
    local ot = require("livecode.operational-transformation")
    local util = require("livecode.util")
	local client = nil

	before_each(function()
		tu.setUpBuffer(input)
		if client  then
			client.active_conn.sock:close()
		end
		client = tu.setup_test_client()
	end)

	it("text is entered from an edit message", function()
        -- setup
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming")
			coroutine.resume(co)
		end, 100)
        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.INSERT,
				0,
				11,
				0,
				0,
                0,
                1,
				{"!"}
			)

        local req = {
            util.MESSAGE_TYPE.EDIT,
            operation,
            2,
            2,
        }
        local encoded = vim.json.encode(req)

        -- do test simluations
        client.active_conn.callbacks.on_text(encoded)


        -- check results
        coroutine.yield()
        local result = getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)

	it("message is transformed if we have sent changes", function()
        -- setup
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming1")
			coroutine.resume(co)
		end, 100)

		local sent_op = ot.newOperationExtended(
			ot.OPERATION_TYPE.INSERT,
			0,
			0,
			0,
			0,
			0,
			1,
			{"hello "}
		)
		client.sent_changes = sent_op
        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.INSERT,
				0,
				5,
				0,
				0,
                0,
                1,
				{"!"}
			)

        local req = {
            util.MESSAGE_TYPE.EDIT,
            operation,
            2,
            2,
        }
        local encoded = vim.json.encode(req)

        -- do test simluations
        client.active_conn.callbacks.on_text(encoded)


        -- check results
        coroutine.yield()
        local result = getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)
	it("message is transformed if we have pending changes", function()
        -- setup
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming2")
			coroutine.resume(co)
		end, 100)

		local sent_op = ot.newOperationExtended(
			ot.OPERATION_TYPE.INSERT,
			0,
			0,
			0,
			0,
			0,
			1,
			{""}
		)
		client.sent_changes = sent_op


		local pending_op = ot.newOperationExtended(
			ot.OPERATION_TYPE.INSERT,
			0,
			0,
			0,
			0,
			0,
			1,
			{"hello "}
		)
		client.pending_changes:push(pending_op)


        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.INSERT,
				0,
				5,
				0,
				0,
                0,
                1,
				{"!"}
			)

        local req = {
            util.MESSAGE_TYPE.EDIT,
            operation,
            2,
            2,
        }
        local encoded = vim.json.encode(req)

        -- do test simluations
        client.active_conn.callbacks.on_text(encoded)


        -- check results
        coroutine.yield()
        local result = getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)
	it("message is transformed if we have processed changes", function()
        -- setup
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming2")
			coroutine.resume(co)
		end, 100)


		local processed_op = ot.newOperationExtended(
			ot.OPERATION_TYPE.INSERT,
			0,
			0,
			0,
			0,
			0,
			1,
			{"hello "}
		)
		client.processed_changes[2] = processed_op


        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.INSERT,
				0,
				5,
				0,
				0,
                0,
                1,
				{"!"}
			)

        local req = {
            util.MESSAGE_TYPE.EDIT,
            operation,
            1,
            3,
        }
        local encoded = vim.json.encode(req)

        -- do test simluations
        client.active_conn.callbacks.on_text(encoded)


        -- check results
        coroutine.yield()
        local result = getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)
end)