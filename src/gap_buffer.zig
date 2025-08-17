// --------------------------------------------------
// Gap Buffer
//   - https://en.wikipedia.org/wiki/Gap_buffer
// --------------------------------------------------


const std = @import("std");
const Allocator = std.mem.Allocator;


// --------------------------------------------------
const buf_size: u32 = 16;


// --------------------------------------------------
pub const GapBuffer = struct {
    data: [buf_size]u8 = undefined,
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
        if (new_index < 0){ return error.NegativeIndex; }
        if (new_index > self.get_num_elements()) { return error.OverflowIndex; }
        if (self.p_start == new_index){ return; }

        const gap_width = self.p_end + 1 - self.p_start;

        // move left
        if (new_index < self.p_start){
            const diff = self.p_start - new_index;

            // move data to the new location
            @memmove(self.data[self.p_end + 1 - diff .. self.p_end + 1], self.data[self.p_start - diff .. self.p_start]);

            // overwrite old data
            @memset(self.data[new_index .. new_index + gap_width], undefined);

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
            @memset(self.data[new_index .. new_index + gap_width], undefined);

            // update pointers
            self.p_start += diff;
            self.p_end += diff;
        }
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


