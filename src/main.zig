
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
    var doc_mode = mode.DocMode{};

    // Allocations
    // parse and save file data
    const file = try parse_arguments();
    var doc_buffer = try setup_document(allocator, file);
    defer _ = doc_buffer.deinit(allocator);


    // allocate display buffer
    var display_data = try allocator.alloc(u8, display_buf_size);
    defer allocator.free(display_data);
    @memset(display_data, @intFromEnum(CodePoint.NULL));

    const border = try allocator.alloc(u8, doc_config.text_width);
    defer allocator.free(border);
    @memset(border, border_char);


    // first view
    display_data = try doc_buffer.get_display_buffer(display_data, doc_config);
    try display_document(display_data, border, doc_buffer, &doc_mode);


    // input
    const stdin: std.fs.File = std.fs.File.stdin();
    var stdin_buf: [stdin_buf_size]u8 = [_]u8{@intFromEnum(CodePoint.NULL)} ** stdin_buf_size;

    try termios.set_raw_mode();

    while (true){
        _ = try stdin.read(&stdin_buf);
        doc_mode.input(&stdin_buf, doc_buffer, &doc_config);
        @memset(&stdin_buf, @intFromEnum(CodePoint.NULL));

        // line width
        if (doc_mode.update.line_width){
            try doc_buffer.update_cursor_line_width();
            doc_mode.update.line_width = false;
        }

        // update display
        if (doc_mode.update.display){
            // check bounds
            doc_buffer.update_horizontal(&doc_config);

            // clamp cursor position
            doc_buffer.cursor.pos_x = Util.clamp(doc_buffer.cursor.pos_x, 0, doc_buffer.cursor.curr_line_width);
            doc_buffer.cursor.pos_y = Util.clamp(doc_buffer.cursor.pos_y, 0, doc_buffer.doc_height);
            mode.DocMode.update_doc_pos_x(doc_buffer, &doc_config);
            

            // clear memory
            @memset(display_data, @intFromEnum(CodePoint.NULL));
            display_data = try doc_buffer.get_display_buffer(display_data, doc_config);


            const num_lines : u8 = doc_config.text_height + 5;
            clear_screen(num_lines);
            try display_document(display_data, border, doc_buffer, &doc_mode);
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


fn display_document(display_data : []u8, border : []const u8, doc_buffer : *document_buffer.DocumentBuffer, doc_mode : *const mode.DocMode) !void{
    const percentage = doc_buffer.num_elements * 100 / (doc_buffer.num_gap_buffer * (document_buffer.init_size * 2 - 1));

    std.debug.print("Elements: {} Buffers: {} - {}%\n", .{doc_buffer.num_elements, doc_buffer.num_gap_buffer, percentage});
    std.debug.print("Mode: {}\n", .{doc_mode.mode});
    std.debug.print("Cursor: x: {} y: {} - v_x: {}\n", .{doc_buffer.cursor.pos_x, doc_buffer.cursor.pos_y, doc_buffer.cursor.v_pos_x});
    std.debug.print("Document: height: {} curr line length: {}\n", .{doc_buffer.doc_height, doc_buffer.cursor.curr_line_width});

    // document data
    std.debug.print("{s}\n", .{border});

    const first_part = display_data[0..doc_buffer.cursor.display_index];
    const cursor_char = display_data[doc_buffer.cursor.display_index];
    const second_part = display_data[doc_buffer.cursor.display_index+1..];

    const ANSI_CODE_RESET = "\x1B[0m";
    const ANSI_CODE_COLOR = "\x1B[1;47;30m";

    std.debug.print("{s}{s}{c}{s}{s}", .{first_part, ANSI_CODE_COLOR, cursor_char, ANSI_CODE_RESET, second_part});
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
        var buf: [document_buffer.init_size]u8 = [_]u8{@intFromEnum(CodePoint.NULL)} ** document_buffer.init_size;
        const bytes_read = try file.read(&buf);

        if (bytes_read == 0){ break; }

        last_node = try doc_buffer.add_buffer(last_node, buf[0..bytes_read]);

        doc_buffer.num_elements += @intCast(bytes_read);
    }

    try doc_buffer.update_cursor_line_width();
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

    return doc_config;
}



// --------------------------------------------------
// Testing

test {
    // Test imports
     std.testing.refAllDecls(@This());
}


