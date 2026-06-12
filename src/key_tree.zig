
// --------------------------------------------------
// KeyTree (Keymappings)
// Create a Tree of keymappings
// - Keymappings are specified through a sequence of characters (nodes)
// - Only the last node (leaf) of each keymapping contains a DESCRIPTION and a FUNCTION REFERENCE
// --------------------------------------------------


const std = @import("std");

const DocMode = @import("mode.zig").DocMode;
const DocumentBuffer = @import("document_buffer.zig").DocumentBuffer;


// --------------------------------------------------
pub const KeyNode = struct {
    nodes: ?std.ArrayList(*KeyNode),
    symbol: u8,
    description: ?[]const u8,
    function: ?*const fn (*DocMode, *DocumentBuffer, u32) void,

    pub fn create(allocator: std.mem.Allocator, char: u8, description: ?[]const u8, function: ?*const fn (*DocMode, *DocumentBuffer, u32) void) !*KeyNode {
        var new_key_node = try allocator.create(KeyNode);

        new_key_node.nodes = null;
        new_key_node.symbol = char;
        new_key_node.description = description;
        new_key_node.function = function;

        return new_key_node;
    }

    pub fn deinit(self: *const KeyNode, allocator: std.mem.Allocator) void {
        defer allocator.destroy(self);

        const is_leaf = self.nodes == null;
        if (is_leaf) return;

        // Free sub nodes
        for (self.nodes.?.items) |key_node| key_node.deinit(allocator);

        // Free ArrayList
        self.nodes.?.deinit();
    }
};


// --------------------------------------------------
pub const KeyTree = struct {
    nodes: ?std.ArrayList(*KeyNode),
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator) !*KeyTree {
       var new_key_tree = try allocator.create(KeyTree);

       new_key_tree.nodes = std.ArrayList(*KeyNode).init(allocator);
       new_key_tree.allocator = allocator;

       return new_key_tree;
    }

    pub fn deinit(self: *KeyTree, allocator: std.mem.Allocator) void {
        defer allocator.destroy(self);

        const is_leaf = self.nodes == null;
        if (is_leaf) return;

        // Free sub nodes
        for (self.nodes.?.items) |key_node| key_node.deinit(allocator);

        // Free ArrayList
        self.nodes.?.deinit();
    }

    pub fn insert_key(self: *KeyTree, sequence: []const u8, description: []const u8, function: *const fn (*DocMode, *DocumentBuffer, u32) void) !void {
        var iter: *std.ArrayList(*KeyNode) = &self.nodes.?;

        outer: for (sequence, 0..) |char, i| {
            // Note: do not duplicate KeyNodes - use existing nodes if possible
            for (iter.items) |item| {
                if (item.symbol != char) continue;

                iter = &item.nodes.?;
                continue :outer;
            }

            // Create new KeyNode
            const last_symbol: bool = i == sequence.len - 1;
            const set_description: ?[]const u8 = if (last_symbol) description else null; 
            const set_function = if (last_symbol) function else null;

            const new_key_node = try KeyNode.create(self.allocator, char, set_description, set_function);
            new_key_node.nodes = std.ArrayList(*KeyNode).init(self.allocator);

            try iter.append(new_key_node);
            iter = &new_key_node.nodes.?;
        }
    }

    pub fn get_function(self: *KeyTree, sequence: []const u8) ?*const fn (*DocMode, *DocumentBuffer, u32) void {
        var iter: *std.ArrayList(*KeyNode) = &self.nodes.?;

        outer: for (sequence, 0..) |char, i| {
            for (iter.items) |key_node| {
                if (key_node.symbol != char) continue;

                const last_char = i == sequence.len - 1;
                if (last_char) return key_node.function;

                iter = &key_node.nodes.?;
                continue :outer;
            }
        }

        return null;
    }

    pub fn print(self: *KeyTree) void {
        std.debug.print("\nPrint KeyTree:\n", .{});
        const is_leaf = self.nodes == null;
        if (is_leaf) return;

        const iter: *std.ArrayList(*KeyNode) = &self.nodes.?;
        help_print(iter, 1);
    }

    fn help_print(iter: *std.ArrayList(*KeyNode), space: u8) void {
        if (iter.items.len == 0) return;

        for (iter.items) |item| {
            for (0..space) |_| std.debug.print("\t", .{});

            std.debug.print("{c}: {s}\n", .{item.symbol, item.description orelse "" });
            help_print(&item.nodes.?, space + 1);
        }
    }
};

