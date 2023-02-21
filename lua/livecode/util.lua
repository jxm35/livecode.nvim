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

}

local OPERATION_TYPE = {
    INSERT = 1,

    DELETE = 2,

    ACK = 3,

}

return {
    MESSAGE_TYPE = MESSAGE_TYPE,
    OPERATION_Type = OPERATION_TYPE
}
