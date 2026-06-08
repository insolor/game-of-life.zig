const std = @import("std");
const testing = std.testing;

/// Asserts that all fields of the structs are equal
pub fn expectEqualStructs(expected: anytype, actual: anytype) !void {
    inline for (@typeInfo(@TypeOf(expected)).@"struct".fields) |field| {
        try testing.expectEqual(
            @field(expected, field.name),
            @field(actual, field.name),
        );
    }
}
