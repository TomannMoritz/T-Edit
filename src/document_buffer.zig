// --------------------------------------------------
// DocumentBuffer
// --------------------------------------------------


const std = @import("std");


const gap_buffer = @import("gap_buffer.zig");
const config = @import("config.zig");



pub const Cursor = struct {
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
    pos_x : u32,
    pos_y : u32,
    doc_height : u32,

    pub fn create(allocator : std.mem.Allocator) !*DocumentBuffer {
        const doc_buf = try allocator.create(DocumentBuffer);
        doc_buf.head = null;
        doc_buf.tail = null;
        doc_buf.cursor = Cursor{
            .pos_x = 0,
            .pos_y = 0,
            .at_eol = false,
            .display_index = 0,
            .curr_line_width = 0,
        };
        doc_buf.pos_x = 0;
        doc_buf.pos_y = 0;
        doc_buf.doc_height = 0;

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

    pub fn add_buffer(self: *DocumentBuffer, node : ?*DocumentNode, allocator : std.mem.Allocator, data : []const u8) !*DocumentNode {
        var new_node = try DocumentNode.create(allocator, data);

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

    pub fn update_cursor_buf(self: *DocumentBuffer, buffer : []u8, cfg : config.Config) ![]u8 {
        // configuration
        const vertical_min = self.pos_y;
        const vertical_max = self.pos_y +| (cfg.text_height -| 1);

        const horizontal_min = self.pos_x;
        const horizontal_max = self.pos_x +| (cfg.text_width -| 1);

        // iterate buffers
        var iter = self.head;
        var line_counter : u32 = 0;
        var col_counter : u32 = 0;

        var char_counter : u32 = 0;
        var curr_line_counter : u32 = 0;

        while (iter) |node| {
            const node_data = node.g_buffer.?.data;

            for (node_data) |ele| {
                if (ele == 0){ continue; }

                // cursor position
                const horizontal_pos = col_counter == self.cursor.pos_x;
                const vertical_pos = line_counter == self.cursor.pos_y;
                if (vertical_pos and horizontal_pos){
                        self.cursor.display_index = char_counter;
                }

                // fill buffer
                const in_vertical_range = line_counter >= vertical_min and line_counter <= vertical_max;
                const in_horizontal_range = col_counter >= horizontal_min and col_counter <= horizontal_max;
                if (in_vertical_range and in_horizontal_range){
                    buffer[char_counter] = ele;
                    char_counter += 1;

                    if (vertical_pos){ curr_line_counter += 1; }
                }

                // add cut off new lines
                if (in_vertical_range and !in_horizontal_range){
                    if (buffer[char_counter -| 1] != 10){
                        buffer[char_counter] = 10;
                        char_counter += 1;
                    }
                }

                col_counter += 1;

                // new line character
                if (ele == 10){
                    // limit horizontal position to eol
                    if (vertical_pos){
                        self.cursor.curr_line_width = curr_line_counter -| 1;
                    }

                    line_counter += 1;
                    col_counter = 0;
                }
            }

            iter = node.next;
        }

        self.doc_height = line_counter;
        return buffer;
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


