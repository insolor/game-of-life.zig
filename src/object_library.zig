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

pub fn putObject(field: *Field, obj: []const u8, x: isize, y: isize) void {
    var row_iterator = std.mem.splitSequence(u8, obj, "\n");
    var i: isize = 0;
    while (row_iterator.next()) |row| : (i += 1) {
        var j: isize = 0;
        for (row) |char|{
            if (char != ' ') {
                field.setOn(x + @as(isize, j), y + i);
            }
            j += 1;
        }
    }
}
