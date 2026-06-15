
// --------------------------------------------------
// imports
const std = @import("std");

const CodePoint = @import("codepoint.zig").CodePoint;

const document_buffer = @import("document_buffer.zig");
const config = @import("config.zig");
const mode = @import("mode.zig");


pub fn clear_screen(num_lines: u8) void {
    const ANSI_CURSOR_UP = 'A';
    const ANSI_ERASE_END_OF_SCREEN = "0J";

    std.debug.print("{u}[{d}{c}", .{@intFromEnum(CodePoint.ESCAPE), num_lines, ANSI_CURSOR_UP});
    std.debug.print("{u}[{s}", .{@intFromEnum(CodePoint.ESCAPE), ANSI_ERASE_END_OF_SCREEN});
}


pub fn display_document(display_data: []u8, border: []const u8, doc_buffer: *document_buffer.DocumentBuffer, doc_mode: *const mode.DocMode, cfg: *const config.Config) !void{
    const percentage = doc_buffer.num_elements * 100 / @max(1, (doc_buffer.num_gap_buffer * (document_buffer.init_size * 2 - 1)));

    std.debug.print("Sequence: {s}\n", .{doc_mode.sequence_buffer});
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

    std.debug.print("{s}{s}{c}{s}{s}\n", .{first_part, ANSI_CODE_COLOR, cursor_char, ANSI_CODE_RESET, second_part});

    // NOTE: the buffer will always contain at least on line to insert new text
    var num_lines: u8 = 1;
    for (display_data) |ele| {
        if (ele == '\n'){ num_lines += 1; }
    }

    // NOTE: keep constant display window size
    // Insert missing lines
    while(num_lines <= cfg.text_height){
        std.debug.print("~\n", .{});
        num_lines += 1;
    }

    std.debug.print("{s}\n", .{border});
}
