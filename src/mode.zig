// --------------------------------------------------
// Mode
// --------------------------------------------------


const std = @import("std");

const CodePoint = @import("codepoint.zig").CodePoint;

const DocumentBuffer = @import("document_buffer.zig").DocumentBuffer;
const Config = @import("config.zig").Config;



pub const Mode = enum {
    Normal,
    Insert,
    Exit,

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
        var result: bool = false;
        const ver_offset : u32 = cfg.offset_vertical;
        const ver_height : u32 = @min(doc_buffer.doc_height, cfg.text_height);

        // quit
        if (key == 'q'){
            self.mode = Mode.Exit;
        }


        // delete characters
        // delete under cursor
        if (key == 'x'){
            if (doc_buffer.delete_right(1)) |_| {
            }else |err| {
                std.debug.print("ERROR: {any}\n", .{err});
            }
            result = true;
        }

        // delete left of cursor
        // special case:
        //      the cursor can be at the first character in the current buffer
        //      as a result a previous buffer with characters is required
        //  => move cursor left and delete towards the right side
        //  => additionally the cursor is already at the correct position
        if (key == 'X'){
            const pos_x_before : u32 = doc_buffer.cursor.pos_x;
            const new_key = 'h';
            _ = parse_normal_mode(self, new_key, doc_buffer, cfg);
            const pos_x_after : u32 = doc_buffer.cursor.pos_x;

            if (pos_x_before == pos_x_after){ return false; }

            if (doc_buffer.delete_right(1)) |_| {
            }else |err| {
                std.debug.print("ERROR: {any}\n", .{err});
            }
            result = true;
        }

        // insert mode
        if (key == 'i'){
            self.mode = Mode.Insert;
        }

        // move left
        if (key == 'h'){
            doc_buffer.cursor.pos_x = doc_buffer.cursor.pos_x -| 1;

            if (doc_buffer.cursor.pos_x < doc_buffer.pos_x + cfg.offset_horizontal){
                doc_buffer.pos_x = doc_buffer.pos_x -| 1;
            }
            doc_buffer.cursor.v_pos_x = doc_buffer.cursor.pos_x;
            doc_buffer.v_pos_x = doc_buffer.pos_x;
            result = true;
        }

        // move right
        if (key == 'l'){
            const new_pos_x = @min(doc_buffer.cursor.pos_x + 1, doc_buffer.cursor.curr_line_width);
            doc_buffer.cursor.pos_x = new_pos_x;

            if (doc_buffer.pos_x + cfg.text_width < doc_buffer.cursor.pos_x + cfg.offset_horizontal + 1){
                doc_buffer.pos_x += 1;
            }
            doc_buffer.cursor.v_pos_x = doc_buffer.cursor.pos_x;
            doc_buffer.v_pos_x = doc_buffer.pos_x;
            result = true;
        }

        // move up
        if (key == 'k'){
            doc_buffer.cursor.pos_y = doc_buffer.cursor.pos_y -| 1;

            // move document up
            if (doc_buffer.cursor.pos_y < doc_buffer.pos_y + ver_offset){
                doc_buffer.pos_y = doc_buffer.pos_y -| 1;
            }
            result = true;
        }

        // move down
        if (key == 'j'){
            doc_buffer.cursor.pos_y = doc_buffer.cursor.pos_y +| 1;

            // move document down
            if (doc_buffer.cursor.pos_y + ver_offset + 1 > doc_buffer.pos_y + ver_height and doc_buffer.pos_y + ver_height < doc_buffer.doc_height){
                doc_buffer.pos_y = doc_buffer.pos_y +| 1;
            }
            result = true;
        }

        return result;
    }

    pub fn update_doc_pos_x(doc_buffer : *DocumentBuffer, doc_config : *const Config) void {
        if (doc_buffer.pos_x > doc_buffer.cursor.pos_x){
            const diff = doc_buffer.pos_x -| doc_buffer.cursor.pos_x;

            doc_buffer.pos_x = doc_buffer.pos_x -| diff -| doc_config.offset_horizontal;
        }
    }


    fn parse_insert_mode(self: *DocMode, key : u8, doc_buffer: *DocumentBuffer) bool {
        _ = doc_buffer;
        if (@intFromEnum(CodePoint.ESCAPE) == key){
            self.mode = Mode.Normal;
        }

        return false;
    }
};


