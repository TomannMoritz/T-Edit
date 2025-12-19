// --------------------------------------------------
// DocumentBuffer
// --------------------------------------------------


const std = @import("std");


const CodePoint = @import("codepoint.zig").CodePoint;

const gap_buffer = @import("gap_buffer.zig");
const config = @import("config.zig");


pub const init_size = gap_buffer.buf_size / 2;


pub const Cursor = struct {
    v_pos_x : u32,
    pos_x : u32,
    pos_y : u32,
    at_eol : bool,
    display_index : u32,
    curr_line_width : u32,
};



pub const DocumentNode = struct {
    g_buffer: ?gap_buffer.GapBuffer = null,
    next: ?*DocumentNode,
    prev: ?*DocumentNode,

    pub fn create(allocator : std.mem.Allocator, data : []const u8) !*DocumentNode {
        var new_doc_node = try allocator.create(DocumentNode);
        new_doc_node.next = null;
        new_doc_node.prev = null;

        var new_gap_buf = gap_buffer.GapBuffer{};
        try new_gap_buf.init(data);

        new_doc_node.g_buffer = new_gap_buf;
        return new_doc_node;
    }

    pub fn deinit(self: *DocumentNode, allocator : std.mem.Allocator) void {
        allocator.destroy(self);
    }
};

pub const DocumentBuffer = struct {
    head : ?*DocumentNode,
    tail : ?*DocumentNode,
    cursor : Cursor,
    v_pos_x : u32,
    pos_x : u32,
    pos_y : u32,
    doc_height : u32,
    buf_index : u32,
    num_elements: u32,
    num_gap_buffer: u32,
    allocator : std.mem.Allocator,

    pub fn create(allocator : std.mem.Allocator) !*DocumentBuffer {
        const doc_buf = try allocator.create(DocumentBuffer);
        doc_buf.head = null;
        doc_buf.tail = null;
        doc_buf.cursor = Cursor{
            .v_pos_x = 0,
            .pos_x = 0,
            .pos_y = 0,
            .at_eol = false,
            .display_index = 0,
            .curr_line_width = 0,
        };
        doc_buf.v_pos_x = 0;
        doc_buf.pos_x = 0;
        doc_buf.pos_y = 0;
        doc_buf.doc_height = 0;
        doc_buf.buf_index = 0;
        doc_buf.num_elements = 0;
        doc_buf.num_gap_buffer = 0;
        doc_buf.allocator = allocator;

        return doc_buf;
    }

    pub fn deinit(self : *DocumentBuffer, allocator : std.mem.Allocator) void {
        // deinit all nodes
        var iter = self.head;

        while (iter) |node| {
            iter = node.next;
            node.deinit(allocator);
        }

        // deinit document buffer
        allocator.destroy(self);
    }

    pub fn add_buffer(self: *DocumentBuffer, node : ?*DocumentNode, data : []const u8) !*DocumentNode {
        var new_node = try DocumentNode.create(self.allocator, data);

        // update document info
        for (data) |ele| {
            if (@intFromEnum(CodePoint.NEW_LINE) == ele){
                self.doc_height += 1;
            }
        }


        // first node
        if (node == null){
            self.head = new_node;
            return new_node;
        }


        // insert new node after node
        new_node.next = node.?.next;
        node.?.next = new_node;

        if (new_node.next != null){
            new_node.next.?.prev = new_node;
        }
        new_node.prev = node;


        if (new_node.next == null){
            self.tail = new_node;
        }

        self.num_gap_buffer += 1;
        return new_node;
    }


    pub fn get_node_line_start(self: *DocumentBuffer, line_index: u32) ?*DocumentNode{
        var line_counter : u32 = 0;
        var iter = self.head;

        while (iter) |node| : (iter = node.next){
            // find buffer with current line start
            line_counter += node.g_buffer.?.num_new_lines;

            if (line_counter < line_index){ continue; }
            return node;
        }

        return null;
    }


    pub fn update_cursor_line_width(self: *DocumentBuffer) !void {
        var iter = self.get_node_line_start(self.cursor.pos_y);
        var line_counter : u32 = self.cursor.pos_y -| 1;
        var col_counter : u32 = 0;

        outer_loop : while (iter) |node| : (iter = node.next) {
            // enumerate line width
            const node_data = node.g_buffer.?.data;

            for (node_data) |ele| {
                if (line_counter > self.cursor.pos_y){ break :outer_loop; }

                switch (ele) {
                    @intFromEnum(CodePoint.NULL) => continue,
                    @intFromEnum(CodePoint.NEW_LINE) => line_counter += 1,
                    else => {
                        if (line_counter == self.cursor.pos_y){
                            col_counter += 1;
                        }
                    }
                }

            }
        }
        
        self.cursor.curr_line_width = col_counter;
    }


    pub fn get_display_buffer(self: *DocumentBuffer, buffer: []u8, cfg: config.Config) ![]u8 {
        // configuration
        const vertical_min = self.pos_y;
        const vertical_max = self.pos_y +| (cfg.text_height -| 1);

        const horizontal_min = self.pos_x;
        const horizontal_max = self.pos_x +| (cfg.text_width -| 1);

        // counters
        var iter = self.get_node_line_start(self.pos_y);
        var line_counter : u32 = self.pos_y -| 1;
        var col_counter : u32 = 0;

        var ele_counter : u32 = 0;

        outer_loop : while (iter) |node| : (iter = node.next) {
            const node_data = node.g_buffer.?.data;

            for (node_data) |ele| {
                if (@intFromEnum(CodePoint.NULL) == ele){ continue; }
                if (line_counter == vertical_max and col_counter > horizontal_max){ break :outer_loop; }
                if (line_counter > vertical_max){ break :outer_loop; }

                // cursor position
                const horizontal_pos = col_counter == self.cursor.pos_x;
                const vertical_pos = line_counter == self.cursor.pos_y;

                if (vertical_pos and horizontal_pos){
                    self.cursor.display_index = ele_counter;
                }

                // document display range
                const in_vertical_range = line_counter >= vertical_min and line_counter <= vertical_max;
                const in_horizontal_range = col_counter >= horizontal_min and col_counter <= horizontal_max;


                if (@intFromEnum(CodePoint.NEW_LINE) == ele){
                    line_counter += 1;
                    col_counter = 0;

                    // keep new line characters outside of the horizontal range
                    if (in_vertical_range){
                        // insert space for the cursor before new line character
                        buffer[ele_counter] = @intFromEnum(CodePoint.SPACE);
                        buffer[ele_counter + 1] = ele;
                        ele_counter += 2;
                    }
                    continue;
                }


                // fill buffer
                if (in_horizontal_range and in_vertical_range){
                    buffer[ele_counter] = ele;
                    ele_counter += 1;
                }

                col_counter += 1;
            }
        }
        
        return buffer;
    }


    pub fn get_buf_cursor(self: *DocumentBuffer) !*DocumentNode {
        var line_counter : u32 = 0;
        var col_counter : u32 = 0;

        var iter = self.head;

        while (iter) |node| : (iter = node.next){
            const node_data = node.g_buffer.?.data;

            var buf_counter : u32 = 0;
            for (node_data) |ele| {
                if (@intFromEnum(CodePoint.NULL) == ele){ continue; }

                const horizontal_pos = col_counter == self.cursor.pos_x;
                const vertical_pos = line_counter == self.cursor.pos_y;
                if (horizontal_pos and vertical_pos){
                    self.buf_index = buf_counter;
                    return node;
                }

                col_counter += 1;

                if (@intFromEnum(CodePoint.NEW_LINE) == ele){
                    line_counter += 1;
                    col_counter = 0;
                }
                buf_counter += 1;
            }
        }
        return error.OutOfBounds;
    }

    pub fn update_horizontal(self: *DocumentBuffer, doc_config : *const config.Config) void {
        const can_jump_further = self.cursor.v_pos_x >= self.cursor.pos_x; 
        const diff_pos_x = self.cursor.pos_x != self.cursor.v_pos_x;

        if (can_jump_further and diff_pos_x){
            self.cursor.pos_x = @min(self.cursor.v_pos_x, self.cursor.curr_line_width);
            self.pos_x = @min(self.v_pos_x, self.cursor.curr_line_width -| doc_config.offset_horizontal);
        }
    }


    pub fn delete_right(self: *DocumentBuffer, num_char: u32) !void {
        const cursor_node = try self.get_buf_cursor();
        var deleted_char : u32 = 0;

        var iter : ?*DocumentNode = cursor_node;
        while (iter) |node| : (iter = node.next){
            const num_ele = node.g_buffer.?.get_num_elements();

            // move cursor to position
            try node.g_buffer.?.move_buffer(self.buf_index);

            const delete_char_right = num_char -| deleted_char;
            const del_data = node.g_buffer.?.delete_right(delete_char_right);
            try self.update_doc_cursor_delete(&del_data);


            const num_del = num_ele - node.g_buffer.?.get_num_elements();
            deleted_char += num_del;
            if (deleted_char >= num_char){
                break;
            }
        }

        self.num_elements = self.num_elements -| deleted_char;
    }


    fn update_doc_cursor_delete(self : *DocumentBuffer, del_data : []const u8) !void {
        var update_line_width : bool = false;

        for (del_data) |ele| {
            // TODO: fix: delted data contains null characters
            if (@intFromEnum(CodePoint.NULL) == ele){ continue; }
            if (@intFromEnum(CodePoint.NEW_LINE) == ele){
                update_line_width = true;
                self.doc_height -= 1;
                continue;
            }

            // normal characters
            if (self.cursor.curr_line_width > 0){
                self.cursor.curr_line_width -= 1;
            }
        }

        if (update_line_width){
            try self.update_cursor_line_width();
        }
    }


    pub fn insert_data(self: *DocumentBuffer, chars : []const u8) !void {
        var inserted_char : u32 = 0;

        while (inserted_char < chars.len){
            // TODO: move once when entering insert mode
            const cursor_node = try self.get_buf_cursor();
            // move cursor to position
            try cursor_node.g_buffer.?.move_buffer(self.buf_index);

            const ins_data = cursor_node.g_buffer.?.insert_data(chars[inserted_char..]);
            inserted_char += @intCast(ins_data.len);

            self.update_doc_cursor_insert(ins_data);

            if (inserted_char < chars.len){
                const sec_half = try cursor_node.g_buffer.?.delete_second_half();
                _ = try self.add_buffer(cursor_node, &sec_half);
            }
        }

        self.num_elements += @intCast(chars.len);
    }

    fn update_doc_cursor_insert(self : *DocumentBuffer, ins_data : []const u8) void {
        for (ins_data) |ele| {
            if (@intFromEnum(CodePoint.NEW_LINE) == ele){
                const line_width : u32 = self.cursor.curr_line_width;
                const width_left : u32 = line_width - self.cursor.pos_x;

                self.cursor.curr_line_width = width_left;
                self.cursor.v_pos_x = 0;
                self.cursor.pos_x = 0;
                self.cursor.pos_y += 1;
                self.doc_height += 1;
                continue;
            }

            // normal characters
            self.cursor.pos_x += 1;
            self.cursor.v_pos_x = self.cursor.pos_x;

            self.cursor.curr_line_width += 1;
        }
    }


    pub fn get_buf_data(node : *DocumentNode) ![16]u8 {
        return node.g_buffer.?.data;
    }


    pub fn print_buffer(self : *DocumentBuffer) !void {
        var doc_iter = self.head;

        while (doc_iter) |node| {
            const data = node.g_buffer.?.data;
            std.debug.print("{s}", .{data});

            doc_iter = node.next;
        }
        std.debug.print("\n", .{});
    }
};


