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

        const gap_size = self.p_end - self.p_start;

        // move left
        if (new_index < self.p_start){
            const diff = self.p_start - new_index;

            // move data to the new location
            @memmove(self.data[self.p_end + 1 - diff .. self.p_end + 1], self.data[self.p_start - diff .. self.p_start]);

            // overwrite old data
            @memset(self.data[new_index .. new_index + gap_size], undefined);

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
            @memset(self.data[new_index .. new_index + gap_size], undefined);

            // update pointers
            self.p_start += diff;
            self.p_end += diff;
        }
    }
};


// --------------------------------------------------
// TODO: testing

