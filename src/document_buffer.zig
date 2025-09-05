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

        // first node
        if (node == null){
            self.head = new_node;
            return new_node;
        }


        new_node.next = node.?.next;
        node.?.next = new_node;

        if (new_node.next != null){
            new_node.next.?.prev = new_node;
        }
        new_node.prev = node;


        if (new_node.next == null){
            self.tail = new_node;
        }

        return new_node;
    }


    // TODO: proper fast implementation
    pub fn update_cursor_buf(self: *DocumentBuffer, buffer : []u8, cfg : config.Config) ![]u8 {
        // configuration
        const vertical_min = self.pos_y;
        const vertical_max = self.pos_y +| (cfg.text_height -| 1);

        const horizontal_min = self.pos_x;
        const horizontal_max = self.pos_x +| (cfg.text_width -| 1);

        // iterate buffers
        var iter = self.head;
        var buf_index : u32 = 0;

        var line_counter : u32 = 0;
        var col_counter : u32 = 0;


        while (iter) |node| : (iter = node.next) {
            const node_data = node.g_buffer.?.data;

            for (node_data) |ele| {
                if (@intFromEnum(CodePoint.NULL) == ele){ continue; }


                // cursor position
                const horizontal_pos = col_counter == self.cursor.pos_x;
                const vertical_pos = line_counter == self.cursor.pos_y;

                if (vertical_pos and horizontal_pos){
                    self.cursor.display_index = buf_index;
                }


                // end of line
                if (@intFromEnum(CodePoint.NEW_LINE) == ele){
                    // create space after new line character
                    buffer[buf_index] = ele;
                    buf_index += 2;


                    // limit horizontal position to eol
                    if (vertical_pos){
                        self.cursor.curr_line_width = col_counter;
                    }

                    line_counter += 1;
                    col_counter = 0;
                    continue;
                }


                // fill buffer
                const in_vertical_range = line_counter >= vertical_min and line_counter <= vertical_max;
                const in_horizontal_range = col_counter >= horizontal_min and col_counter <= horizontal_max;

                if (in_vertical_range and in_horizontal_range){
                    buffer[buf_index] = ele;
                    buf_index += 1;
                }

                col_counter += 1;
            }
        }

        self.doc_height = line_counter;
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
            _ = node.g_buffer.?.delete_right(delete_char_right);


            const num_del = num_ele - node.g_buffer.?.get_num_elements();
            deleted_char += num_del;
            if (deleted_char >= num_char){
                break;
            }
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

            // TODO: update index
            self.cursor.pos_x += @intCast(ins_data.len);

            if (inserted_char < chars.len){
                const sec_half = try cursor_node.g_buffer.?.delete_second_half();
                _ = try self.add_buffer(cursor_node, &sec_half);
            }
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


