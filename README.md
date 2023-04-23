# LiveCode nvim plugin

for dev run `nvim --cmd "set rtp+=./"`

## Commands

- `startServer(host, port)` - Create a server on the specified host and port, and share the current buffer
- `joinServer(host, port)` - Join a server on the specified host and port
- `stop` - Stop or leave the server
- `setBuffer` - Set the current buffer to buffer shared in the session

### Help
- To join a session on another device on your wifi network get that devices ip address on the network.
- This can be found on mac/linux by running the command ` ipconfig getifaddr en0`
or on windows by running the command `ipconfig /all`.
- The ip address should take the form `192.168.*.*`
