package.loaded["livecode"] = nil
-- package.loaded['livecode.test-module'] = nil
package.loaded["livecode.serve"] = nil
package.loaded["dev"] = nil

vim.api.nvim_set_keymap("n", ",t", "<cmd>luafile dev/init.lua<cr>", {})

Livecode = require("livecode")

vim.api.nvim_set_keymap("n", ",w", ":lua Livecode.test()<cr>", {})

-- vim.api.nvim_set_keymap("n", ",c", ":lua Livecode.startServer()<cr>", {})
vim.api.nvim_set_keymap("n", ",c", ":lua Livecode.StartServer()<cr>", {})
-- vim.api.nvim_set_keymap("n", ",s", ":lua Livecode.start()<cr>", {})
vim.api.nvim_set_keymap("n", ",s", ":lua Livecode.StartSession()<cr>", {})
vim.api.nvim_set_keymap("n", ",j", ":lua Livecode.Join()<cr>", {})
vim.api.nvim_set_keymap("n", ",b", ":lua Livecode.SetActiveBuffer()<cr>", {})

vim.api.nvim_set_keymap("n", ",d", ":lua Livecode.stopServer()<cr>", {})
vim.api.nvim_set_keymap("n", ",r", ":lua Livecode.join('192.168.0.16', 11359)<cr>", {})
-- vim.api.nvim_set_keymap("n", ",j", ":lua Livecode.join()<cr>", {})
vim.api.nvim_set_keymap("n", ",l", ":lua Livecode.stop()<cr>", {})
--vim.api.nvim_set_keymap("n", ",c", ":lua Livecode.client()<cr>", {})
