// --------------------------------------------------
// Mode
// --------------------------------------------------


const std = @import("std");

const CodePoint = @import("codepoint.zig").CodePoint;

const DocumentBuffer = @import("document_buffer.zig").DocumentBuffer;
const Config = @import("config.zig").Config;


const buf_size = 1024;


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


    pub fn input(self: *DocMode, buffer : [buf_size]u8, doc_buffer: *DocumentBuffer, cfg : *const Config) bool {
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

        // insert mode
        if (key == 'i'){
            self.mode = Mode.Insert;
        }

        // move left
        if (key == 'h'){
            doc_buffer.cursor.pos_x = doc_buffer.cursor.pos_x -| 1;
            result = true;
        }

        // move right
        if (key == 'l'){
            const new_pos_x = @min(doc_buffer.cursor.pos_x + 1, doc_buffer.cursor.curr_line_width);
            doc_buffer.cursor.pos_x = new_pos_x;
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


    fn parse_insert_mode(self: *DocMode, key : u8, doc_buffer: *DocumentBuffer) bool {
        _ = doc_buffer;
        if (CodePoint.ESCAPE.equal_to(key)){
            self.mode = Mode.Normal;
        }

        return false;
    }
};


