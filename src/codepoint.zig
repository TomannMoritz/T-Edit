// --------------------------------------------------
// CodePoints
// --------------------------------------------------


// TODO: ASCII -> UTF
pub const CodePoint = enum(u8){
    NULL = 0,
    NEW_LINE = 10,
    ESCAPE = 27,
    CURSOR = 33,

    pub fn get_value(self : *const CodePoint) u8 {
        return @intFromEnum(self.*);
    }

    pub fn equal_to(self : *const CodePoint, value : u8) bool {
        return @intFromEnum(self.*) == value;
    }

    pub fn not_equal_to(self : *const CodePoint, value : u8) bool {
        return @intFromEnum(self.*) != value;
    }
};

