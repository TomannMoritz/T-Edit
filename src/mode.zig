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


pub const DocMode = struct {
    mode : Mode,


    pub fn is_exit(self: *DocMode) bool {
        return self.mode == Mode.Exit;
    }


    pub fn input(self: *DocMode, buffer : []u8, doc_buffer: *DocumentBuffer, cfg : *const Config) bool {
        // TODO: evaluate further inputs
        const key: u8 = buffer[0];

        switch (self.mode){
            Mode.Normal => return self.parse_normal_mode(key, doc_buffer, cfg),
            Mode.Insert => return self.parse_insert_mode(key, doc_buffer),
            Mode.Exit => return false,
        }
    }


    fn parse_normal_mode(self: *DocMode, key: u8, doc_buffer: *DocumentBuffer, cfg : *const Config) bool {
        var update_buffer: bool = false;
        const ver_offset : u32 = cfg.offset_vertical;
        const ver_height : u32 = @min(doc_buffer.doc_height, cfg.text_height);


        // --------------------------------------------------
        // special
        // quit
        if (key == @intFromEnum(Key.QUIT)){
            self.mode = Mode.Exit;
            return false;
        }


        // --------------------------------------------------
        // movement
        // move left
        if (key == @intFromEnum(Key.MOVE_LEFT)){
            doc_buffer.cursor.pos_x = doc_buffer.cursor.pos_x -| 1;

            if (doc_buffer.cursor.pos_x < doc_buffer.pos_x + cfg.offset_horizontal){
                doc_buffer.pos_x = doc_buffer.pos_x -| 1;
            }
            doc_buffer.cursor.v_pos_x = doc_buffer.cursor.pos_x;
            doc_buffer.v_pos_x = doc_buffer.pos_x;
            update_buffer = true;
        }

        // move right
        if (key == @intFromEnum(Key.MOVE_RIGHT)){
            const new_pos_x = @min(doc_buffer.cursor.pos_x + 1, doc_buffer.cursor.curr_line_width);
            doc_buffer.cursor.pos_x = new_pos_x;

            if (doc_buffer.pos_x + cfg.text_width < doc_buffer.cursor.pos_x + cfg.offset_horizontal + 1){
                doc_buffer.pos_x += 1;
            }
            doc_buffer.cursor.v_pos_x = doc_buffer.cursor.pos_x;
            doc_buffer.v_pos_x = doc_buffer.pos_x;
            update_buffer = true;
        }

        // move up
        if (key == @intFromEnum(Key.MOVE_LINE_UP)){
            doc_buffer.cursor.pos_y = doc_buffer.cursor.pos_y -| 1;

            // move document up
            if (doc_buffer.cursor.pos_y < doc_buffer.pos_y + ver_offset){
                doc_buffer.pos_y = doc_buffer.pos_y -| 1;
            }
            update_buffer = true;
        }

        // move down
        if (key == @intFromEnum(Key.MOVE_LINE_DOWN)){
            doc_buffer.cursor.pos_y = doc_buffer.cursor.pos_y +| 1;

            // move document down
            if (doc_buffer.cursor.pos_y + ver_offset + 1 > doc_buffer.pos_y + ver_height and doc_buffer.pos_y + ver_height < doc_buffer.doc_height){
                doc_buffer.pos_y = doc_buffer.pos_y +| 1;
            }
            update_buffer = true;
        }


        // --------------------------------------------------
        // delete characters
        // delete under cursor
        if (key == @intFromEnum(Key.REMOVE_UNDER_CURSOR)){
            if (doc_buffer.delete_right(1)) |_| {
            }else |err| {
                std.debug.print("ERROR: {any}\n", .{err});
            }
            update_buffer = true;
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

            if (pos_x_before == pos_x_after){ return false; }

            if (doc_buffer.delete_right(1)) |_| {
            }else |err| {
                std.debug.print("ERROR: {any}\n", .{err});
            }
            update_buffer = true;
        }


        // --------------------------------------------------
        // insert mode
        if (key == @intFromEnum(Key.INSERT_UNDER_CURSOR)){
            self.mode = Mode.Insert;
        }

        return update_buffer;
    }


    pub fn update_doc_pos_x(doc_buffer : *DocumentBuffer, doc_config : *const Config) void {
        if (doc_buffer.pos_x > doc_buffer.cursor.pos_x){
            const diff = doc_buffer.pos_x -| doc_buffer.cursor.pos_x;

            doc_buffer.pos_x = doc_buffer.pos_x -| diff -| doc_config.offset_horizontal;
        }
    }


    fn parse_insert_mode(self: *DocMode, key : u8, doc_buffer: *DocumentBuffer) bool {
        _ = doc_buffer;
        if (key == @intFromEnum(CodePoint.ESCAPE)){
            self.mode = Mode.Normal;
        }

        return false;
    }
};


