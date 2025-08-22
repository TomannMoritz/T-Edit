
// --------------------------------------------------
// imports
const std = @import("std");


// --------------------------------------------------
// local imports
const CodePoint = @import("codepoint.zig").CodePoint;
const Util = @import("util.zig");

const document_buffer = @import("document_buffer.zig");
const termios = @import("termios.zig");
const config = @import("config.zig");
const mode = @import("mode.zig");

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

    // try doc_buffer.print_buffer();


    // setup configuration
    const doc_config = setup_config();


    // allocate display buffer
    var display_data = try allocator.alloc(u8, 512);
    defer allocator.free(display_data);


    // termios
    try termios.set_raw_mode();

    var buffer: [1024]u8 = undefined;
    const stdin: std.fs.File = std.fs.File.stdin();

    var doc_mode = mode.DocMode{.mode = mode.Mode.Normal};

    const border = try allocator.alloc(u8, doc_config.text_width);
    defer allocator.free(border);

    @memset(border, '-');

    // first view
    display_data = try doc_buffer.update_cursor_buf(display_data, doc_config);
    display_data[doc_buffer.cursor.display_index] = 33;
    display_document(display_data, border);

    while (true){
        _ = try stdin.read(&buffer);

        const changed = doc_mode.input(buffer, doc_buffer, &doc_config);

        if (changed){
            // update display buffer
            @memset(display_data, undefined);
            display_data = try doc_buffer.update_cursor_buf(display_data, doc_config);

            // clamp cursor position
            doc_buffer.cursor.pos_x = Util.clamp(doc_buffer.cursor.pos_x, 0, doc_buffer.cursor.curr_line_width);
            doc_buffer.cursor.pos_y = Util.clamp(doc_buffer.cursor.pos_y, 0, doc_buffer.doc_height);
            _ = try doc_buffer.update_cursor_buf(display_data, doc_config);

            if (CodePoint.NEW_LINE.equal_to(display_data[doc_buffer.cursor.display_index])){
                display_data[doc_buffer.cursor.display_index + 1] = CodePoint.NEW_LINE.get_value();
            }
            display_data[doc_buffer.cursor.display_index] = CodePoint.CURSOR.get_value();

            std.debug.print("MODE: {}\n", .{doc_mode.mode});
            std.debug.print("Cursor: x: {} y: {}\n", .{doc_buffer.cursor.pos_x, doc_buffer.cursor.pos_y});
            std.debug.print("Document: height: {} curr line length: {}\n", .{doc_buffer.doc_height, doc_buffer.cursor.curr_line_width});
            display_document(display_data, border);
        }

        if (doc_mode.is_exit()){ break; }
    }

    try termios.reset_mode();
    std.debug.print("\n", .{});
}


fn display_document(display_data : []u8, border : []const u8) void{
    std.debug.print("{s}", .{border});
    std.debug.print("\n{s}\n", .{display_data});
    std.debug.print("{s}\n", .{border});
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
        .offset_horizontal = 2,
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


