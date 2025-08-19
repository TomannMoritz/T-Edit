
const std = @import("std");


const gap_buffer = @import("gap_buffer.zig");


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

    pub fn create(allocator : std.mem.Allocator) !*DocumentBuffer {
        const doc_buf = try allocator.create(DocumentBuffer);
        doc_buf.head = null;
        doc_buf.tail = null;

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

    pub fn get_buf_data(node : *DocumentNode) ![16]u8 {
        return node.g_buffer.?.data;
    }
};


