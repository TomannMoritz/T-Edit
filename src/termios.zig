// --------------------------------------------------
// Termios
// Set terminal mode (canonical) and flags
// --------------------------------------------------

const std = @import("std");

var old_termios_config : ?std.posix.termios = null; 
const tcsa : std.posix.TCSA = std.posix.TCSA.NOW;


pub fn set_raw_mode() !void {
    if (old_termios_config) |_| { return error.TermiosConfigAvailable; }

    old_termios_config = try std.posix.tcgetattr(std.posix.STDIN_FILENO);

    // create new config
    var new_termios_config = old_termios_config;

    // Dont print pressed keys
    new_termios_config.?.lflag.ECHO = false;
    new_termios_config.?.lflag.ICANON = false;

    try std.posix.tcsetattr(std.posix.STDIN_FILENO, tcsa, new_termios_config.?);
}


pub fn reset_mode() !void {
    if (old_termios_config) |old_config| {
        try std.posix.tcsetattr(std.posix.STDIN_FILENO, tcsa, old_config);
        return;
    }

    return error.TermiosConfigInvalid;
}


