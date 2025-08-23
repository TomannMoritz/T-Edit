
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
const display_buf_size = 512;
const stdin_buf_size = 8;

const border_char = '-';


// --------------------------------------------------
pub fn main() !void {
    // create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // setup configuration
    const doc_config = setup_config();
    var doc_mode = mode.DocMode{.mode = mode.Mode.Normal};

    // Allocations
    // parse and save file data
    const file = try parse_arguments();
    var doc_buffer = try setup_document(allocator, file);
    defer _ = doc_buffer.deinit(allocator);

    // allocate display buffer
    var display_data = try allocator.alloc(u8, display_buf_size);
    defer allocator.free(display_data);

    const border = try allocator.alloc(u8, doc_config.text_width);
    defer allocator.free(border);
    @memset(border, border_char);

    // first view
    display_data = try doc_buffer.update_cursor_buf(display_data, doc_config);
    display_data[doc_buffer.cursor.display_index] = @intFromEnum(CodePoint.CURSOR);
    display_document(display_data, border, doc_buffer, &doc_mode);


    // input
    const stdin: std.fs.File = std.fs.File.stdin();
    var stdin_buf: [stdin_buf_size]u8 = undefined;

    try termios.set_raw_mode();

    while (true){
        _ = try stdin.read(&stdin_buf);
        const data_changed = doc_mode.input(&stdin_buf, doc_buffer, &doc_config);

        // update display
        if (data_changed){
            // get new line information
            _ = try doc_buffer.update_cursor_buf(display_data, doc_config);
            doc_buffer.update_horizontal(&doc_config);

            // clamp cursor position
            doc_buffer.cursor.pos_x = Util.clamp(doc_buffer.cursor.pos_x, 0, doc_buffer.cursor.curr_line_width);
            doc_buffer.cursor.pos_y = Util.clamp(doc_buffer.cursor.pos_y, 0, doc_buffer.doc_height);
            mode.DocMode.update_doc_pos_x(doc_buffer, &doc_config);

            // clear memory
            @memset(display_data, undefined);
            display_data = try doc_buffer.update_cursor_buf(display_data, doc_config);

            const cursor_index = doc_buffer.cursor.display_index;
            const cursor_char : u8 = display_data[cursor_index];
            if (@intFromEnum(CodePoint.NEW_LINE) == cursor_char){
                display_data[cursor_index + 1] = @intFromEnum(CodePoint.NEW_LINE);
            }
            display_data[cursor_index] = @intFromEnum(CodePoint.CURSOR);

            const num_lines : u8 = doc_config.text_height + 5;
            clear_screen(num_lines);
            display_document(display_data, border, doc_buffer, &doc_mode);
        }

        if (doc_mode.is_exit()){ break; }
    }

    try termios.reset_mode();
    std.debug.print("\n", .{});
}


fn clear_screen(num_lines : u8) void {
    const ANSI_CURSOR_UP = 'A';
    const ANSI_ERASE_END_OF_SCREEN = "0J";

    std.debug.print("{u}[{d}{c}", .{@intFromEnum(CodePoint.ESCAPE), num_lines, ANSI_CURSOR_UP});
    std.debug.print("{u}[{s}", .{@intFromEnum(CodePoint.ESCAPE), ANSI_ERASE_END_OF_SCREEN});
}


fn display_document(display_data : []u8, border : []const u8, doc_buffer : *document_buffer.DocumentBuffer, doc_mode : *const mode.DocMode) void{
    std.debug.print("Mode: {}\n", .{doc_mode.mode});
    std.debug.print("Cursor: x: {} y: {} - v_x: {}\n", .{doc_buffer.cursor.pos_x, doc_buffer.cursor.pos_y, doc_buffer.cursor.v_pos_x});
    std.debug.print("Document: height: {} curr line length: {}\n", .{doc_buffer.doc_height, doc_buffer.cursor.curr_line_width});
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


