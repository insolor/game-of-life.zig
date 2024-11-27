const std = @import("std");
const models = @import("models.zig");
const Field = models.Field;

pub const GLIDER =
    \\ #
    \\  #
    \\###
;

pub const SPACESHIP =
    \\#  #
    \\    #
    \\#   #
    \\ ####
;

pub fn putObject(field: Field, obj: []const u8, x: isize, y: isize) void {
    var row_iterator = std.mem.split(u8, obj, "\n");
    var i: usize = 0;
    while (row_iterator.next()) |row| : (i += 1) {
        for (row, 0..) |char, j| {
            if (char != ' ') {
                field.setOn(x + j, y + i);
            }
        }
    }
}
