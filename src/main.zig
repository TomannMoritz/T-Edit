
// --------------------------------------------------
// imports
const std = @import("std");


// --------------------------------------------------
// local imports
const gap_buffer = @import("gap_buffer.zig");


// --------------------------------------------------
pub fn main() !void {
    std.debug.print("Main:\n", .{});

}



// --------------------------------------------------
// Testing

test {
    // Test imports
     std.testing.refAllDecls(@This());
}


