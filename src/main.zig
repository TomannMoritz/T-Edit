
// --------------------------------------------------
// imports
const std = @import("std");


// --------------------------------------------------
// local imports
const document_buffer = @import("document_buffer.zig");
const config = @import("config.zig");


// --------------------------------------------------
const buf_size = 8;


// --------------------------------------------------
pub fn main() !void {
    std.debug.print("Main:\n", .{});

    // create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();


    // parse and save file data
    const file = try parse_arguments();
    var doc_buffer = try setup_document(allocator, file);
    defer _ = doc_buffer.deinit(allocator);

    try doc_buffer.print_buffer();


    // setup configuration
    const doc_config = setup_config();


    // allocate display buffer
    var display_data = try allocator.alloc(u8, 512);
    defer allocator.free(display_data);

    display_data = try doc_buffer.update_cursor_buf(display_data, doc_config);
    display_data[doc_buffer.cursor.display_index] = 33;

    std.debug.print("Display:\n{s}\n\n", .{display_data});
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

        last_node = try doc_buffer.add_buffer(last_node, allocator, &buf);
    }

    return doc_buffer;
}


fn setup_config() config.Config {
    // TODO: customize configuration
    const doc_config = config.Config{
        .text_height = 10,
        .text_width = 25,
        .offset_vertical = 1,
        .offset_right = 5,
    };

    // TODO: implement offsets with cursor movement

    return doc_config;
}



// --------------------------------------------------
// Testing

test {
    // Test imports
     std.testing.refAllDecls(@This());
}


