# LiveCode nvim plugin
- Live collaborative coding in your Neovim, all in lua

## Preview

## Features

- Live text editing, with all your favourite vim features
- Built in local host and local network server
- Fast, Reliable Operational Transaction algorithm keeping documents in sync
- Support for all motions, lsp's and other plugins

## Install

- With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
	use({
		"jxm35/livecode.nvim",
		config = function()
			require("livecode")
		end,
	})

```

- With [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'jxm35/livecode.nvim'

" Somewhere after plug#end()
lua require('livecode')
```

## Commands

- `:LCStartSession [port]` - Create a session on the specified port available on your local wifi network, and share the current buffer.
- `:LCJoin [host] [port]` - Join a server on the specified host and port
- `:LCStop` - Stop or leave the server
- `:LCShareBuffer` - Set the current buffer to be the buffer shared in the session

### Help
- `Livecode.nvim` provides help docs which can be accessed by running `:help livecode-nvim`
- To join a session on another device on your wifi network get that devices ip address on the network.
- This can be found on mac/linux by running the command ` ipconfig getifaddr en0`
or on windows by running the command `ipconfig /all`.
- The ip address should take the form `192.168.*.*`

### Credits

- [instant.nvim](https://github.com/jbyuki/instant.nvim) - Sadly no lomger maintained, but it helped me to design this plugin.
- [plugin-template.nvim](https://github.com/m00qek/plugin-template.nvim) - Helped structure the project and tests.
