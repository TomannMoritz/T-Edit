
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


// --------------------------------------------------
// Testing
// --------------------------------------------------
fn test_function(_: *DocMode, _: *DocumentBuffer, _: u32) void { }

test "create KeyTree" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var new_key_tree = try KeyTree.create(allocator);
    defer new_key_tree.deinit(allocator);
}


test "create KeyNode" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const char: u8 = 'a';
    const description: []const u8 = "Description";

    const new_key_node = try KeyNode.create(allocator, char, description, null);
    defer new_key_node.deinit(allocator);


    try std.testing.expectEqual(new_key_node.symbol, char);
    try std.testing.expectEqual(new_key_node.description, description);
}


test "create KeyTree - KeyNode" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var new_key_tree = try KeyTree.create(allocator);
    defer new_key_tree.deinit(allocator);

    const sequence: []const u8 = "ab";
    const description: []const u8 = "Description";
    try new_key_tree.insert_key(sequence, description, test_function);

    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].symbol, sequence[0]);
    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].nodes.?.items[0].symbol, sequence[1]);

    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].description, null);
    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].nodes.?.items[0].description, description);
}


test "create KeyTree - KeyNodes" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var new_key_tree = try KeyTree.create(allocator);
    defer new_key_tree.deinit(allocator);


    const sequence_1: []const u8 = "ab";
    const description_1: []const u8 = "Description 1";

    const sequence_2: []const u8 = "acd";
    const description_2: []const u8 = "Description 2";

    const sequence_3: []const u8 = "ad";
    const description_3: []const u8 = "Description 3";

    try new_key_tree.insert_key(sequence_1, description_1, test_function);
    try new_key_tree.insert_key(sequence_2, description_2, test_function);
    try new_key_tree.insert_key(sequence_3, description_3, test_function);

    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].symbol, sequence_1[0]);
    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].nodes.?.items[0].symbol, sequence_1[1]);

    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].symbol, sequence_2[0]);
    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].nodes.?.items[1].symbol, sequence_2[1]);
    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].nodes.?.items[1].nodes.?.items[0].symbol, sequence_2[2]);

    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].symbol, sequence_3[0]);
    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].nodes.?.items[2].symbol, sequence_3[1]);

    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].description, null);
    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].nodes.?.items[0].description, description_1);
    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].nodes.?.items[1].description, null);
    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].nodes.?.items[1].nodes.?.items[0].description, description_2);
    try std.testing.expectEqual(new_key_tree.nodes.?.items[0].nodes.?.items[2].description, description_3);

    new_key_tree.print();
}

