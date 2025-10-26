// --------------------------------------------------
// CodePoints
// --------------------------------------------------


// TODO: ASCII -> UTF
pub const CodePoint = enum(u8){
    NULL = 0,
    NEW_LINE = 10,
    ESCAPE = 27,
    SPACE = 32,
    CURSOR = 33,
};

