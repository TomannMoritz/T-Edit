// --------------------------------------------------
// Util
// --------------------------------------------------


pub fn clamp(value : u32, min_value : u32, max_value : u32) u32 {
    return @max(min_value, @min(max_value, value));
}

