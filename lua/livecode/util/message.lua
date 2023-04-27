-- File containing shared utility functions
--

local MESSAGE_TYPE = {

	CONNECT = 1,

	DISCONNECT = 2,

	WELCOME = 3,

	INFO = 4,

	GET_BUFFER = 5,

	BUFFER_CONTENT = 6,

	EDIT = 7,

	ACK = 8,
}

return {
	MESSAGE_TYPE = MESSAGE_TYPE,
}
