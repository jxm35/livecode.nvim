local function test_func()
	local file = vim.fn.expand("%:p")
	print("my file is - " .. file)
end

return test_func
