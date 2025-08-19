
// --------------------------------------------------
// imports
const std = @import("std");


// --------------------------------------------------
// local imports
const gap_buffer = @import("gap_buffer.zig");
const document_buffer = @import("document_buffer.zig");


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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var doc_buffer = try document_buffer.DocumentBuffer.create(allocator);
    defer _ = doc_buffer.deinit(allocator);

    var last_node : ?*document_buffer.DocumentNode = null;

    // save file data
    while (true) {
        var buf: [buf_size]u8 = undefined;
        const bytes_read = try file.read(&buf);

        if (bytes_read == 0){ break; }

        std.debug.print("Bytes read: '{}'\n", .{bytes_read});
        last_node = try doc_buffer.add_buffer(last_node, allocator, &buf);
    }



    var doc_iter = doc_buffer.head;
    
    while (doc_iter) |node| {
        const data = try document_buffer.DocumentBuffer.get_buf_data(node);
        std.debug.print("{s}", .{data});

        doc_iter = node.next;
    }
}



// --------------------------------------------------
// Testing

test {
    // Test imports
     std.testing.refAllDecls(@This());
}


