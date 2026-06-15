
// --------------------------------------------------
// imports
const std = @import("std");


// --------------------------------------------------
// local imports
const CodePoint = @import("codepoint.zig").CodePoint;
const Util = @import("util.zig");

const document_buffer = @import("document_buffer.zig");
const termios = @import("termios.zig");
const display = @import("display.zig");
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

    // Allocations
    // parse and save file data
    const file_data = try parse_arguments();
    var doc_buffer = try setup_document(allocator, file_data.file);
    defer _ = doc_buffer.deinit(allocator);

    // setup configuration
    const doc_config = config.Config.setup_config();
    var doc_mode = try mode.DocMode.create(allocator, file_data.path);
    defer doc_mode.deinit();


    // allocate display buffer
    const display_data = try allocator.alloc(u8, display_buf_size);
    defer allocator.free(display_data);
    @memset(display_data, @intFromEnum(CodePoint.NULL));

    const border = try allocator.alloc(u8, doc_config.text_width);
    defer allocator.free(border);
    @memset(border, border_char);


    // first view
    try doc_buffer.update_display_buffer(display_data, doc_config);
    try display.display_document(display_data, border, doc_buffer, doc_mode, &doc_config);


    // input
    const stdin: std.fs.File = std.fs.File.stdin();
    var stdin_buf: [stdin_buf_size]u8 = [_]u8{@intFromEnum(CodePoint.NULL)} ** stdin_buf_size;

    try termios.set_raw_mode();

    while (true){
        _ = try stdin.read(&stdin_buf);
        try doc_mode.input(&stdin_buf, doc_buffer, &doc_config);
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
            try doc_buffer.update_display_buffer(display_data, doc_config);


            const num_lines: u8 = doc_config.text_height + 7;
            display.clear_screen(num_lines);
            try display.display_document(display_data, border, doc_buffer, doc_mode, &doc_config);
        }

        if (doc_mode.is_exit()){ break; }
    }

    try termios.reset_mode();
    std.debug.print("\n", .{});
}


fn parse_arguments() !struct {file: ?std.fs.File, path: []const u8} {
    const args = std.os.argv;

    if (args.len != 2){
        std.debug.print("[!] Invalid number of arguments: {}\n", .{args.len});
        return error.InvalidArguments;
    }

    const path_null_terminated = args[1];
    const file_path: []const u8 = std.mem.sliceTo(path_null_terminated, 0);

    const file = std.fs.cwd().openFile(file_path, .{}) catch { return .{.file = null, .path = file_path}; };
    return .{.file = file, .path = file_path};
}


fn setup_document(allocator: std.mem.Allocator, file: ?std.fs.File) !*document_buffer.DocumentBuffer {
    var doc_buffer = try document_buffer.DocumentBuffer.create(allocator);
    var last_node: ?*document_buffer.DocumentNode = null;
    if (file == null){ return doc_buffer; }

    // save file data
    while (true) {
        var buf: [document_buffer.init_size]u8 = [_]u8{@intFromEnum(CodePoint.NULL)} ** document_buffer.init_size;
        const bytes_read = try file.?.read(&buf);

        if (bytes_read == 0){ break; }

        last_node = try doc_buffer.add_buffer(last_node, buf[0..bytes_read]);

        // update document info
        doc_buffer.update_doc_info_insert(buf[0..bytes_read]);
    }

    try doc_buffer.update_cursor_line_width();
    return doc_buffer;
}


// --------------------------------------------------
// Testing

test {
    // Test imports
     std.testing.refAllDecls(@This());
}


