local tu = require("tests.test_utils")

describe("check edit messages (insert):", function()
	local testModule = require("livecode")
    local ot = require("livecode.operational-transformation")
    local util = require("livecode.util")
	local client = nil

	it("type letter", function()
		local input = [[hello world]]
		local expected = [[hello world!]]
		tu.setUpBuffer(input)
		if client  then
			client.active_conn.sock:close()
		end
		client = tu.setup_test_client()
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
        local result = tu.getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)

	it("paste word", function()
		local input = [[hello !]]
		local expected = [[hello world!]]
		tu.setUpBuffer(input)
		if client  then
			client.active_conn.sock:close()
		end
		client = tu.setup_test_client()
        -- setup
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming")
			coroutine.resume(co)
		end, 100)
        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.INSERT,
				0,
				6,
				0,
				0,
                0,
                5,
				{"world"}
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
        local result = tu.getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)

	it("newline (o)", function()
		local input = [[hello
world]]
		local expected = [[hello

world]]
		tu.setUpBuffer(input)
		if client  then
			client.active_conn.sock:close()
		end
		client = tu.setup_test_client()
        -- setup
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming")
			coroutine.resume(co)
		end, 100)
        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.INSERT,
				1,
				0,
				0,
				0,
                1,
                0,
				{"", ""}
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
        local result = tu.getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)

	it("enter key (middle of line)", function()
		local input = [[helloworld!]]
		local expected = [[hello
world!]]
		tu.setUpBuffer(input)
		if client  then
			client.active_conn.sock:close()
		end
		client = tu.setup_test_client()
        -- setup
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming")
			coroutine.resume(co)
		end, 100)
        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.INSERT,
				0,
				5,
				0,
				0,
                1,
                0,
				{"", "world"}
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
        local result = tu.getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)

	it("lsp insert if then", function()
		local input = [[]]
		local expected = [[if  then
    
end]]
		tu.setUpBuffer(input)
		if client  then
			client.active_conn.sock:close()
		end
		client = tu.setup_test_client()
        -- setup
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming")
			coroutine.resume(co)
		end, 100)
        
		-- the insert is done in 3 parts
		-- if
        local ifOperation = ot.newOperationExtended(
				ot.OPERATION_TYPE.INSERT,
				0,
				0,
				0,
				0,
                0,
                3,
				{"if "}
			)

        local ifReq = {
            util.MESSAGE_TYPE.EDIT,
            ifOperation,
            2,
            2,
        }
        local ifEncoded = vim.json.encode(ifReq)

		-- then + newline
		local thenOperation = ot.newOperationExtended(
				ot.OPERATION_TYPE.INSERT,
				0,
				3,
				0,
				0,
                1,
                4,
				{" then", "    "}
			)

        local thenReq = {
            util.MESSAGE_TYPE.EDIT,
            thenOperation,
            2,
            2,
        }
        local thenEncoded = vim.json.encode(thenReq)

		-- end
		local endOperation = ot.newOperationExtended(
				ot.OPERATION_TYPE.INSERT,
				1,
				4,
				0,
				0,
                1,
                3,
				{"", "end"}
			)

        local endReq = {
            util.MESSAGE_TYPE.EDIT,
            endOperation,
            2,
            2,
        }
        local endEncoded = vim.json.encode(endReq)

        -- do test simluations
        client.active_conn.callbacks.on_text(ifEncoded)
		client.active_conn.callbacks.on_text(thenEncoded)
		client.active_conn.callbacks.on_text(endEncoded)


        -- check results
        coroutine.yield()
        local result = tu.getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)
end)

describe("check edit messages (delete):", function()
	local testModule = require("livecode")
    local ot = require("livecode.operational-transformation")
    local util = require("livecode.util")
	local client = nil


	it("deletes a letter", function()
		local input = [[hello world!]]
		local expected = [[hello world]]
        -- setup
		tu.setUpBuffer(input)
		if client  then
			client.active_conn.sock:close()
		end
		client = tu.setup_test_client()
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming")
			coroutine.resume(co)
		end, 100)
        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.DELETE,
				0,
				11,
				0,
				1,
                0,
                0,
				{""}
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
        local result = tu.getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)

	it("deletes a word", function()
		local input = [[hello world!]]
		local expected = [[hello!]]
        -- setup
		tu.setUpBuffer(input)
		if client  then
			client.active_conn.sock:close()
		end
		client = tu.setup_test_client()
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming")
			coroutine.resume(co)
		end, 100)
        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.DELETE,
				0,
				5,
				0,
				6,
                0,
                0,
				{""}
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
        local result = tu.getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)
	it("deletes a line (dd)", function()
		local input = [[the
		world
		is
		yours]]
		local expected = [[the
		world
		yours]]
        -- setup
		tu.setUpBuffer(input)
		if client  then
			client.active_conn.sock:close()
		end
		client = tu.setup_test_client()
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming")
			coroutine.resume(co)
		end, 100)
        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.DELETE,
				2,
				0,
				1,
				0,
                0,
                0,
				{""}
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
        local result = tu.getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)
	it("deletes across lines", function()

		local input = [[first line of text
on the second line
third line of text
finally]]
		local expected = [[first line of text
on the second line of text
finally]]
        -- setup
		tu.setUpBuffer(input)
		if client  then
			client.active_conn.sock:close()
		end
		client = tu.setup_test_client()
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming")
			coroutine.resume(co)
		end, 100)
        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.DELETE,
				1,
				13,
				1,
				5,
                0,
                0,
				{""}
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
        local result = tu.getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)
	it("deletes first character of line", function()

		local input = [[first line of text
on the second line
third line of text
finally]]
		local expected = [[first line of text
on the second linethird line of text
finally]]
        -- setup
		tu.setUpBuffer(input)
		if client  then
			client.active_conn.sock:close()
		end
		client = tu.setup_test_client()
		local co = coroutine.running()
		vim.defer_fn(function()
            print("coroutine resuming")
			coroutine.resume(co)
		end, 100)
        
        local operation = ot.newOperationExtended(
				ot.OPERATION_TYPE.DELETE,
				1,
				18, -- length of previous line
				1,
				0,
                0,
                0,
				{""}
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
        local result = tu.getBufLines()
        assert.are.same(vim.split(expected, "\n"), result)
	end)
	
end)