const std = @import("std");
const builtin = std.builtin;
const testing = std.testing;

fn get_struct_fields(comptime T: type) []const builtin.Type.StructField {
    return @typeInfo(T).@"struct".fields;
}

/// Asserts that all fields of the structs are equal
pub fn expectEqualStructs(expected: anytype, actual: anytype) !void {
    inline for (get_struct_fields(@TypeOf(actual))) |field| {
        try testing.expectEqual(
            @field(expected, field.name),
            @field(actual, field.name),
        );
    }
}
