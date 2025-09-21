// --------------------------------------------------
// Mode
// --------------------------------------------------


const std = @import("std");

const CodePoint = @import("codepoint.zig").CodePoint;

const DocumentBuffer = @import("document_buffer.zig").DocumentBuffer;
const Config = @import("config.zig").Config;


pub const Key = enum(u8){
    // special
    QUIT = 'q',

    // movement
    MOVE_LINE_DOWN = 'j',
    MOVE_LINE_UP = 'k',
    MOVE_RIGHT = 'l',
    MOVE_LEFT = 'h',

    // deletion
    REMOVE_BEFORE_CURSOR = 'X',
    REMOVE_UNDER_CURSOR = 'x',

    // insertion
    INSERT_UNDER_CURSOR = 'i',
};


pub const Mode = enum {
    Normal,
    Insert,
    Exit,

    // TODO: command mode (save & quit)
};


pub const Update = struct {
    line_width: bool = false,
    display: bool = false
};


pub const DocMode = struct {
    mode: Mode = Mode.Normal,
    update: Update = Update{},


    pub fn is_exit(self: *DocMode) bool {
        return self.mode == Mode.Exit;
    }


    pub fn input(self: *DocMode, buffer : []u8, doc_buffer: *DocumentBuffer, cfg : *const Config) void {
        // TODO: evaluate further inputs
        const key: u8 = buffer[0];

        switch (self.mode){
            Mode.Normal => self.parse_normal_mode(key, doc_buffer, cfg),
            Mode.Insert => self.parse_insert_mode(key, doc_buffer),
            Mode.Exit => {},
        }

        _ = check_document_bounds(doc_buffer, cfg);
    }


    fn parse_normal_mode(self: *DocMode, key: u8, doc_buffer: *DocumentBuffer, cfg : *const Config) void {
        // --------------------------------------------------
        // special
        // quit
        if (key == @intFromEnum(Key.QUIT)){
            self.mode = Mode.Exit;
            return;
        }

        // --------------------------------------------------
        // movement
        // TODO: update display only when required (out of bounds)
        // move left
        if (key == @intFromEnum(Key.MOVE_LEFT)){
            doc_buffer.cursor.pos_x = doc_buffer.cursor.pos_x -| 1;

            doc_buffer.cursor.v_pos_x = doc_buffer.cursor.pos_x;
            doc_buffer.v_pos_x = doc_buffer.pos_x;

            self.update.display = true;
        }

        // move right
        if (key == @intFromEnum(Key.MOVE_RIGHT)){
            doc_buffer.cursor.pos_x = doc_buffer.cursor.pos_x +| 1;

            doc_buffer.cursor.v_pos_x = doc_buffer.cursor.pos_x;
            doc_buffer.v_pos_x = doc_buffer.pos_x;

            self.update.display = true;
        }

        // move up
        if (key == @intFromEnum(Key.MOVE_LINE_UP)){
            doc_buffer.cursor.pos_y = doc_buffer.cursor.pos_y -| 1;

            self.update.line_width = true;
            self.update.display = true;
        }

        // move down
        if (key == @intFromEnum(Key.MOVE_LINE_DOWN)){
            doc_buffer.cursor.pos_y = doc_buffer.cursor.pos_y +| 1;

            self.update.line_width = true;
            self.update.display = true;
        }


        // --------------------------------------------------
        // delete characters
        // delete under cursor
        if (key == @intFromEnum(Key.REMOVE_UNDER_CURSOR)){
            if (doc_buffer.delete_right(1)) |_| {
            }else |err| {
                std.debug.print("ERROR: {any}\n", .{err});
            }

            self.update.display = true;
        }

        // delete left of cursor
        // special case:
        //      the cursor can be at the first character in the current buffer
        //      as a result a previous buffer with characters is required
        //  => move cursor left and delete towards the right side
        //  => additionally the cursor is already at the correct position
        if (key == @intFromEnum(Key.REMOVE_BEFORE_CURSOR)){
            const pos_x_before : u32 = doc_buffer.cursor.pos_x;
            const new_key : u8 = @intFromEnum(Key.MOVE_LEFT);
            _ = parse_normal_mode(self, new_key, doc_buffer, cfg);
            const pos_x_after : u32 = doc_buffer.cursor.pos_x;

            if (pos_x_before == pos_x_after){ return; }

            if (doc_buffer.delete_right(1)) |_| {
            }else |err| {
                std.debug.print("ERROR: {any}\n", .{err});
            }

            self.update.display = true;
        }


        // --------------------------------------------------
        // insert mode
        if (key == @intFromEnum(Key.INSERT_UNDER_CURSOR)){
            self.mode = Mode.Insert;

            self.update.display = true;
        }
    }


    pub fn update_doc_pos_x(doc_buffer : *DocumentBuffer, doc_config : *const Config) void {
        if (doc_buffer.pos_x > doc_buffer.cursor.pos_x){
            const diff = doc_buffer.pos_x -| doc_buffer.cursor.pos_x;

            doc_buffer.pos_x = doc_buffer.pos_x -| diff -| doc_config.offset_horizontal;
        }
    }


    fn check_document_bounds(doc_buffer : *DocumentBuffer, cfg : *const Config) bool {
        const ver_offset : u32 = cfg.offset_vertical;
        const ver_height : u32 = @min(doc_buffer.doc_height, cfg.text_height);
        var new_document_position : bool = false;


        // --------------------------------------------------
        // horizontal
        // set right bound
        doc_buffer.cursor.pos_x = @min(doc_buffer.cursor.pos_x, doc_buffer.cursor.curr_line_width);

        // move document display left
        const x_cursor_left : u32 = doc_buffer.cursor.pos_x;
        const x_buf_left : u32 = doc_buffer.pos_x + cfg.offset_horizontal;

        if (x_cursor_left < x_buf_left){
            const left_diff : u32 = x_buf_left - x_cursor_left;
            doc_buffer.pos_x = doc_buffer.pos_x -| left_diff;
            new_document_position = true;
        }

        // move document right
        const x_cursor_right : u32 = doc_buffer.cursor.pos_x + cfg.offset_horizontal + 1;
        const x_buf_right : u32 = doc_buffer.pos_x + cfg.text_width;

        if (x_cursor_right > x_buf_right){
            const right_diff : u32 = x_cursor_right - x_buf_right;
            doc_buffer.pos_x += right_diff;
            new_document_position = true;
        }



        // --------------------------------------------------
        // vertical
        // set bottom bound
        doc_buffer.cursor.pos_y = @min(doc_buffer.cursor.pos_y, doc_buffer.doc_height - 1);

        // move document up
        const y_cursor_up : u32 = doc_buffer.cursor.pos_y;
        const y_buf_up : u32 = doc_buffer.pos_y + ver_offset;

        if (y_cursor_up < y_buf_up){
            const up_diff : u32 = y_buf_up - y_cursor_up;
            doc_buffer.pos_y = doc_buffer.pos_y -| up_diff;
            new_document_position = true;
        }

        // move document down
        const y_cursor_down : u32 = doc_buffer.cursor.pos_y + ver_offset + 1;
        const y_buf_down : u32 = doc_buffer.pos_y + ver_height;
        const can_scroll_down : bool = y_buf_down < doc_buffer.doc_height;

        if (y_cursor_down > y_buf_down and can_scroll_down){
            const down_diff : u32 = y_cursor_down - y_buf_down;
            doc_buffer.pos_y = doc_buffer.pos_y +| down_diff;
            new_document_position = true;
        }

        return new_document_position;
    }


    // TODO: update screen/display position
    fn parse_insert_mode(self: *DocMode, key : u8, doc_buffer: *DocumentBuffer) void {
        if (key == @intFromEnum(CodePoint.ESCAPE)){
            self.mode = Mode.Normal;
        }

        const valid_char = 32 <= key and key <= 126;
        const is_enter: bool = key == @intFromEnum(CodePoint.NEW_LINE);

        if (valid_char or is_enter){
            const chars : [1]u8 = [_]u8{key};
            _ = doc_buffer.insert_data(&chars) catch { };

            self.update.display = true;
        }
    }
};


