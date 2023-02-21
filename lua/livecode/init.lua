local test  = require('livecode.test-module')
--local serve = require('livecode.server')
local serve = require('livecode.server')
local join = require('livecode.client')
return {
    test = test,
    startServer = serve.StartServer,
    stopServer = serve.StopServer,
    start = join.start,
    join = join.join,
    stop = join.stop
}
