// --------------------------------------------------
// Mode
// --------------------------------------------------


const std = @import("std");

const CodePoint = @import("codepoint.zig").CodePoint;

const DocumentBuffer = @import("document_buffer.zig").DocumentBuffer;
const Config = @import("config.zig").Config;
const key_tree = @import("key_tree.zig");



pub const Key = enum(u8){
    INVALID = 0,

    // special
    NORMAL_MODE = @intFromEnum(CodePoint.ESCAPE),

    // command mode
    QUIT = 'q',
    WRITE = 'w',
};


pub const Mode = enum {
    Normal,
    Insert,
    Command,
    Exit,

    // TODO: visualization mode
};


pub const Update = struct {
    line_width: bool = false,
    display: bool = false
};


pub const DocMode = struct {
    allocator: std.mem.Allocator,
    mode: Mode,
    update: Update = Update{},
    file_path: []const u8,
    normal_key_tree: *key_tree.KeyTree,
    sequence_buffer: [8]u8,
    sequence_index: u8,

    
    pub fn create(allocator: std.mem.Allocator, file_path: []const u8) !*DocMode {
        var doc_mode = try allocator.create(DocMode);
        doc_mode.allocator = allocator;
        doc_mode.file_path = file_path;
        doc_mode.mode = Mode.Normal;
        doc_mode.reset_buffer();

        // create normal key tree
        doc_mode.normal_key_tree = try key_tree.KeyTree.create(allocator);

        try doc_mode.normal_key_tree.insert_key(&[_]u8{@intFromEnum(Key.NORMAL_MODE)}, "Reset Input Buffer", reset_normal_mode);
        try doc_mode.normal_key_tree.insert_key(":", "Switch into COMMAND Mode", switch_command_mode);
        try doc_mode.normal_key_tree.insert_key("i", "Switch into INSERT Mode", switch_insert_mode);

        try doc_mode.normal_key_tree.insert_key("j", "Move Cursor Down", move_down);
        try doc_mode.normal_key_tree.insert_key("k", "Move Cursor Up", move_up);
        try doc_mode.normal_key_tree.insert_key("h", "Move Cursor Left", move_left);
        try doc_mode.normal_key_tree.insert_key("l", "Move Cursor Right", move_right);

        try doc_mode.normal_key_tree.insert_key("x", "Delete Under Cursor", delete_right);
        try doc_mode.normal_key_tree.insert_key("X", "Delete Before Cursor", delete_left);

        return doc_mode;
    }


    pub fn deinit(self: *DocMode) void {
        defer self.allocator.destroy(self);
        defer self.normal_key_tree.deinit(self.allocator);
    }

    fn reset_buffer(self: *DocMode) void {
        self.sequence_buffer = [_]u8{@intFromEnum(Key.INVALID)} ** self.sequence_buffer.len;
        self.sequence_index = 0;
    }


    pub fn is_exit(self: *DocMode) bool {
        return self.mode == Mode.Exit;
    }


    pub fn input(self: *DocMode, buffer : []u8, doc_buffer: *DocumentBuffer, cfg : *const Config) !void {
        // insert new sequence values
        for (buffer) |ele| {
            if (ele == @intFromEnum(Key.INVALID)) break;
            if (ele == @intFromEnum(Key.NORMAL_MODE)) self.reset_buffer();
            if (self.sequence_index >= self.sequence_buffer.len) break;

            self.sequence_buffer[self.sequence_index] = ele;
            self.sequence_index += 1;
        }

        const sequence = self.sequence_buffer[0..self.sequence_index];
        switch (self.mode){
            Mode.Normal => self.parse_normal_mode(sequence, doc_buffer),
            Mode.Insert => self.parse_insert_mode(sequence, doc_buffer),
            Mode.Command => try self.parse_command_mode(sequence, doc_buffer),
            Mode.Exit => {},
        }

        _ = check_document_bounds(doc_buffer, cfg);
    }


    // --------------------------------------------------
    // Normal Mode
    fn parse_normal_mode(self: *DocMode, sequence: []u8, doc_buffer: *DocumentBuffer) void {
        if (self.normal_key_tree.get_function(sequence) == null) return;

        const function = self.normal_key_tree.get_function(sequence).?;
        function(self, doc_buffer, 1);

        // reset
        self.reset_buffer();
    }


    pub fn reset_normal_mode(self: *DocMode, _: *DocumentBuffer, _: u32) void {
        self.reset_buffer();
    }


    pub fn switch_command_mode(self: *DocMode, _: *DocumentBuffer, _: u32) void {
            self.mode = Mode.Command;
    }


    pub fn switch_insert_mode(self: *DocMode, _: *DocumentBuffer, _: u32) void {
        self.mode = Mode.Insert;

        self.update.display = true;
    }


    pub fn move_left(self: *DocMode, doc_buffer: *DocumentBuffer, counter: u32) void {
        doc_buffer.cursor.pos_x = doc_buffer.cursor.pos_x -| counter;

        doc_buffer.cursor.v_pos_x = doc_buffer.cursor.pos_x;
        doc_buffer.v_pos_x = doc_buffer.pos_x;

        self.update.display = true;
    }


    pub fn move_right(self: *DocMode, doc_buffer: *DocumentBuffer, counter: u32) void {
        doc_buffer.cursor.pos_x = doc_buffer.cursor.pos_x +| counter;

        doc_buffer.cursor.v_pos_x = doc_buffer.cursor.pos_x;
        doc_buffer.v_pos_x = doc_buffer.pos_x;

        self.update.display = true;
    }


    pub fn move_up(self: *DocMode, doc_buffer: *DocumentBuffer, counter: u32) void {
        doc_buffer.cursor.pos_y = doc_buffer.cursor.pos_y -| counter;

        self.update.line_width = true;
        self.update.display = true;
    }


    pub fn move_down(self: *DocMode, doc_buffer: *DocumentBuffer, counter: u32) void {
        doc_buffer.cursor.pos_y = doc_buffer.cursor.pos_y +| counter;

        self.update.line_width = true;
        self.update.display = true;
    }


    pub fn delete_right(self: *DocMode, doc_buffer: *DocumentBuffer, counter: u32) void {
        if (doc_buffer.delete_right(counter)) |_| {
        }else |err| {
            std.debug.print("ERROR: {any}\n", .{err});
        }

        self.update.display = true;
    }


    pub fn delete_left(self: *DocMode, doc_buffer: *DocumentBuffer, counter: u32) void {
        // delete left of cursor
        // special case:
        //      the cursor can be at the first character in the current buffer
        //      as a result a previous buffer with characters is required
        //  => move cursor left and delete towards the right side
        //  => additionally the cursor is already at the correct position
        const pos_x_before : u32 = doc_buffer.cursor.pos_x;
        move_left(self, doc_buffer, counter);
        const pos_x_after : u32 = doc_buffer.cursor.pos_x;

        if (pos_x_before == pos_x_after){ return; }

        if (doc_buffer.delete_right(counter)) |_| {
        }else |err| {
            std.debug.print("ERROR: {any}\n", .{err});
        }

        self.update.display = true;
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
        doc_buffer.cursor.pos_y = @min(doc_buffer.cursor.pos_y, doc_buffer.doc_height);

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


    // --------------------------------------------------
    // Insert Mode
    // TODO: update screen/display position
    fn parse_insert_mode(self: *DocMode, sequence: []u8, doc_buffer: *DocumentBuffer) void {
        for (sequence) |key| {
            // normal mode
            if (key == @intFromEnum(Key.NORMAL_MODE)){
                self.mode = Mode.Normal;
                self.reset_buffer();
                return;
            }

            const valid_char = 32 <= key and key <= 126;
            const is_enter: bool = key == @intFromEnum(CodePoint.NEW_LINE);

            if (valid_char or is_enter){
                const chars : [1]u8 = [_]u8{key};
                _ = doc_buffer.insert_data(&chars) catch { };

                self.update.display = true;
            }
        }

        self.reset_buffer();
    }


    // --------------------------------------------------
    // Command Mode
    fn parse_command_mode(self: *DocMode, sequence: []u8, doc_buffer: *DocumentBuffer) !void {
        for (sequence) |key| {
            // normal mode
            if (key == @intFromEnum(Key.NORMAL_MODE)){
                self.mode = Mode.Normal;
                self.reset_buffer();
                return;
            }

            // quit
            if (key == @intFromEnum(Key.QUIT)){
                self.mode = Mode.Exit;
                self.reset_buffer();
                return;
            }

            // write/save file
            if (key == @intFromEnum(Key.WRITE)){
                // create allocator
                var gpa = std.heap.GeneralPurposeAllocator(.{}){};
                const allocator = gpa.allocator();
                defer _ = gpa.deinit();

                // allocate write buffer
                const buf_write = try allocator.alloc(u8, doc_buffer.num_elements);
                defer allocator.free(buf_write);
                @memset(buf_write, @intFromEnum(CodePoint.NULL));

                try doc_buffer.update_document_buf_data(buf_write);
                try std.fs.cwd().writeFile(.{.sub_path = self.file_path, .data=buf_write});

                self.reset_buffer();
                return;
            }
        }

        self.reset_buffer();
    }
};


