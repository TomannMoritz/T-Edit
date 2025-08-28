// --------------------------------------------------
// Gap Buffer
//   - https://en.wikipedia.org/wiki/Gap_buffer
// --------------------------------------------------


const std = @import("std");
const Allocator = std.mem.Allocator;


const CodePoint = @import("codepoint.zig").CodePoint;


// --------------------------------------------------
const buf_size: u32 = 16;


// --------------------------------------------------
pub const GapBuffer = struct {
    data: [buf_size]u8 = [_]u8{@intFromEnum(CodePoint.NULL)} ** buf_size,
    p_start: u32 = 0,
    p_end: u32 = buf_size - 1,

    pub fn init(self: *GapBuffer, new_data: []const u8) !void {
        if (self.data.len < new_data.len){ return error.OutOfBounds; }

        @memcpy(self.data[0..new_data.len], new_data[0..]);
        self.p_start = @intCast(new_data.len);
    }

    pub fn get_num_elements(self: *GapBuffer) u32 {
        return buf_size - self.p_end - 1 + self.p_start;
    }

    pub fn get_data(self: *GapBuffer, allocator: *Allocator) ![]u8 {
        const gap_size = self.p_end + 1 - self.p_start;

        var raw_data = try allocator.alloc(u8, self.data.len - gap_size);

        @memcpy(raw_data[0..self.p_start], self.data[0..self.p_start]);
        @memcpy(raw_data[self.p_start..], self.data[self.p_end + 1..]);

        return raw_data;
    }

    pub fn get_data_raw(self: *GapBuffer) ![]u8 {
        return &self.data;
    }


    pub fn is_full(self: *GapBuffer) bool {
        return self.p_start == self.p_end;
    }

    pub fn move_buffer(self: *GapBuffer, new_index: u32) !void {
        if (new_index < 0){ return error.IndexUnderflow; }
        if (new_index > self.get_num_elements()) { return error.IndexOverflow; }
        if (self.p_start == new_index){ return; }

        const gap_width = self.p_end + 1 - self.p_start;

        // move left
        if (new_index < self.p_start){
            const diff = self.p_start - new_index;

            // move data to the new location
            @memmove(self.data[self.p_end + 1 - diff .. self.p_end + 1], self.data[self.p_start - diff .. self.p_start]);

            // overwrite old data
            @memset(self.data[new_index .. new_index + gap_width], @intFromEnum(CodePoint.NULL));

            // update pointers
            self.p_start -= diff;
            self.p_end -= diff;
        }


        // move right
        if (new_index > self.p_start){
            const diff = new_index - self.p_start;

            // move data to the new location
            @memmove(self.data[self.p_start .. self.p_start + diff], self.data[self.p_end + 1 .. self.p_end + 1 + diff]);

            // overwrite old data
            @memset(self.data[new_index .. new_index + gap_width], @intFromEnum(CodePoint.NULL));

            // update pointers
            self.p_start += diff;
            self.p_end += diff;
        }
    }

    // Delete characters
    pub fn delete_left(self: *GapBuffer, num_ele: u32) [buf_size]u8 {
        const new_start : u32 = self.p_start -| num_ele;
        const diff_ele : u32 = self.p_start - new_start;

        var deleted_data: [buf_size]u8 = [_]u8{@intFromEnum(CodePoint.NULL)} ** buf_size;
        @memmove(deleted_data[0..diff_ele], self.data[new_start..self.p_start]);
        @memset(self.data[new_start..self.p_start], @intFromEnum(CodePoint.NULL));

        self.p_start = new_start;
        return deleted_data;
    }

    pub fn delete_right(self: *GapBuffer, num_ele: u32) [buf_size]u8 {
        const new_end : u32 = @min(self.p_end + num_ele, buf_size - 1);
        const diff_ele : u32 = new_end - self.p_end;

        var delete_data : [buf_size]u8 = [_]u8{@intFromEnum(CodePoint.NULL)} ** buf_size;
        @memmove(delete_data[0..diff_ele], self.data[self.p_end+1..new_end+1]);
        @memset(self.data[self.p_end+1..new_end+1], @intFromEnum(CodePoint.NULL));

        self.p_end = new_end;
        return delete_data;
    }

    // TODO: get/delete second part/half

    // Insert characters
    pub fn insert_data(self: *GapBuffer, data: []const u8) []const u8 {
        // The current implementation keeps one space occupied for the gap buffer pointers.
        // Therefore the buffer capacity is: buf_size - 1

        const empty_space = self.p_end - self.p_start;
        const insert_ele = @min(empty_space, data.len);

        if (insert_ele == 0){ return &[_]u8{}; }

        const after_start_pos = self.p_start + insert_ele;
        @memmove(self.data[self.p_start .. after_start_pos], data[0..insert_ele]);
        self.p_start = after_start_pos;

        return data[0..insert_ele];
    }
};



// --------------------------------------------------
// Testing
// --------------------------------------------------
const testing = std.testing;


fn test_setup() !GapBuffer {
    const my_data = [_]u8{0, 1, 2, 3, 4, 5, 6, 7};

    var g_buffer = GapBuffer{};
    try g_buffer.init(my_data[0..]);

    try testing.expect(std.mem.eql(u8, g_buffer.data[0..8], &my_data));

    return g_buffer;
}


test "init data" {
    _ = try test_setup();
}


test "move_buffer left/right" {
    var g_buffer = try test_setup();

    const start_position = g_buffer.p_start;
    const start_data = g_buffer.data;

    // move left
    try g_buffer.move_buffer(0);
    try testing.expectEqual(buf_size, g_buffer.data.len);

    // move back
    try g_buffer.move_buffer(start_position);
    try testing.expectEqual(buf_size, g_buffer.data.len);

    try testing.expect(std.mem.eql(u8, g_buffer.data[0..], start_data[0..]));
}


test "delete left data" {
    var g_buffer = try test_setup();

    const start_position = g_buffer.p_start;
    const start_data = g_buffer.data;


    // delete left
    const del_pos = 2;
    const del_data: [buf_size]u8 = g_buffer.delete_left(del_pos);

    try testing.expectEqual(buf_size, g_buffer.data.len);
    try testing.expectEqual(start_position, g_buffer.p_start + del_pos);

    // check deleted data
    const start_part = start_data[g_buffer.p_start..start_position];
    const del_part = del_data[0..del_pos];
    try testing.expect(std.mem.eql(u8, start_part, del_part));

    // check invalid data
    const inv_data = g_buffer.data[g_buffer.p_start..start_position];
    const inv_mem : [del_pos]u8 = [_]u8{@intFromEnum(CodePoint.NULL)} ** del_pos;
    try testing.expect(std.mem.eql(u8, inv_data, &inv_mem));
}


test "delete right data" {
    var g_buffer = try test_setup();

    // move left
    try g_buffer.move_buffer(0);

    const end_position = g_buffer.p_end;
    const start_data = g_buffer.data;


    // delete right
    const del_pos = 3;
    const del_data: [buf_size]u8 = g_buffer.delete_right(del_pos);

    try testing.expectEqual(buf_size, g_buffer.data.len);
    try testing.expectEqual(end_position + del_pos, g_buffer.p_end);

    // check deleted data
    const start_part = start_data[end_position+1..g_buffer.p_end+1];
    const del_part = del_data[0..del_pos];
    try testing.expect(std.mem.eql(u8, start_part, del_part));

    // check invalid data
    const inv_data = g_buffer.data[end_position+1..g_buffer.p_end+1];
    const inv_mem : [del_pos]u8 = [_]u8{@intFromEnum(CodePoint.NULL)} ** del_pos;
    try testing.expect(std.mem.eql(u8, inv_data, &inv_mem));
}


test "insert data" {
    var g_buffer = try test_setup();

    // move left
    try g_buffer.move_buffer(0);

    const insert_data: [3]u8 = [_]u8{3,4,5};
    const result = g_buffer.insert_data(&insert_data);

    try testing.expect(std.mem.eql(u8, result[0..], insert_data[0..]));
    try testing.expect(std.mem.eql(u8, g_buffer.data[0..insert_data.len], &insert_data));
}


test "insert data overflow" {
    var g_buffer = try test_setup();

    // move left
    try g_buffer.move_buffer(0);

    const insert_data: [buf_size]u8 = [_]u8{3} ** buf_size;
    const result = g_buffer.insert_data(&insert_data);

    try testing.expect(std.mem.eql(u8, result[0..], insert_data[0..result.len]));
    try testing.expect(std.mem.eql(u8, g_buffer.data[0..result.len], insert_data[0..result.len]));
}


