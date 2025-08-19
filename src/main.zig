
// --------------------------------------------------
// imports
const std = @import("std");


// --------------------------------------------------
// local imports
const gap_buffer = @import("gap_buffer.zig");


// --------------------------------------------------
const buf_size = 8;


// --------------------------------------------------
pub fn main() !void {
    std.debug.print("Main:\n", .{});

    const args = std.os.argv;

    if (args.len != 2){
        std.debug.print("[!] Invalid number of arguments: {}\n", .{args.len});
        return;
    }

    const path_null_terminated = args[1];
    const file_path: []const u8 = std.mem.sliceTo(path_null_terminated, 0);

    const file = try std.fs.cwd().openFile(file_path, .{});

    while (true) {
        var buf: [buf_size]u8 = undefined;
        const bytes_read = try file.read(&buf);

        if (bytes_read == 0){ break; }

        std.debug.print("Bytes read: '{}'\n", .{bytes_read});
        std.debug.print("FILE: '{any}'\n", .{buf[0..]});
        std.debug.print("FILE: '{s}'\n", .{buf[0..]});
    }
}



// --------------------------------------------------
// Testing

test {
    // Test imports
     std.testing.refAllDecls(@This());
}


