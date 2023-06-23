package.loaded["livecode"] = nil
-- package.loaded['livecode.test-module'] = nil
package.loaded["livecode.serve"] = nil
package.loaded["dev"] = nil

vim.api.nvim_set_keymap("n", ",t", "<cmd>luafile dev/init.lua<cr>", {})

require("livecode").setup()

Livecode = require("livecode")

vim.api.nvim_set_keymap("n", ",c", ":lua Livecode.StartServer()<cr>", {})
vim.api.nvim_set_keymap("n", ",s", ":lua Livecode.StartSession()<cr>", {})
vim.api.nvim_set_keymap("n", ",j", ":lua Livecode.Join()<cr>", {})
vim.api.nvim_set_keymap("n", ",b", ":lua Livecode.SetActiveBuffer()<cr>", {})
vim.api.nvim_set_keymap("n", ",d", ":lua Livecode.Stop()<cr>", {})
