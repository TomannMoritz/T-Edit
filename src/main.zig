
// --------------------------------------------------
// imports
const std = @import("std");


// --------------------------------------------------
// local imports
const document_buffer = @import("document_buffer.zig");


// --------------------------------------------------
const buf_size = 8;


// --------------------------------------------------
pub fn main() !void {
    std.debug.print("Main:\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const file = try parse_arguments();
    var doc_buffer = try setup_document(allocator, file);
    defer _ = doc_buffer.deinit(allocator);

    try doc_buffer.print_buffer();
}


fn parse_arguments() !std.fs.File {
    const args = std.os.argv;

    if (args.len != 2){
        std.debug.print("[!] Invalid number of arguments: {}\n", .{args.len});
        return error.InvalidArguments;
    }

    const path_null_terminated = args[1];
    const file_path: []const u8 = std.mem.sliceTo(path_null_terminated, 0);

    const file = try std.fs.cwd().openFile(file_path, .{});
    return file;
}


fn setup_document(allocator : std.mem.Allocator, file : std.fs.File) !*document_buffer.DocumentBuffer {
    var doc_buffer = try document_buffer.DocumentBuffer.create(allocator);
    var last_node : ?*document_buffer.DocumentNode = null;

    // save file data
    while (true) {
        var buf: [buf_size]u8 = undefined;
        const bytes_read = try file.read(&buf);

        if (bytes_read == 0){ break; }

        std.debug.print("Bytes read: '{}'\n", .{bytes_read});
        last_node = try doc_buffer.add_buffer(last_node, allocator, &buf);
    }

    return doc_buffer;
}



// --------------------------------------------------
// Testing

test {
    // Test imports
     std.testing.refAllDecls(@This());
}


