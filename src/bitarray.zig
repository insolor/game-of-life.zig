const std = @import("std");
const Signedness = std.builtin.Signedness;
const builtin = std.builtin;

fn isUnsignedInt(comptime T: type) bool {
    // Case for zig version < 0.14.0
    if (@hasField(builtin.Type, "Int")) {
        return switch (@typeInfo(T)) {
            .Int => |intInfo| intInfo.signedness == Signedness.unsigned,
            else => false,
        };
    }

    return switch (@typeInfo(T)) {
        .int => |intInfo| intInfo.signedness == Signedness.unsigned,
        else => false,
    };
}

/// At compiletime check that the given type is an unsigned integer (like u32, u64, etc.)
fn ensureIsUnsignedInt(comptime T: type) void {
    if (!isUnsignedInt(T)) {
        @compileError("Expected an unsigned integer type, but got: " ++ @typeName(T));
    }
}

/// Bit iterator for unsigned integers. Iterates over alle the bits of an unsigned integer from least significant
/// to most significant.
fn BitIterator(comptime T: type) type {
    ensureIsUnsignedInt(T);

    return struct {
        value: T,
        index: usize = 0,
        const size: usize = @bitSizeOf(T);

        const Self = @This();

        fn init(value: T) Self {
            return .{
                .value = value,
            };
        }

        /// Each call returns the value of the next bit or null if there are no more bits
        fn next(self: *Self) ?u1 {
            if (self.index >= size) {
                return null;
            }

            const current_value = self.value & 1;
            self.value >>= 1;
            self.index += 1;
            return if (current_value != 0) 1 else 0;
        }
    };
}

pub fn BitArray(comptime T: type) type {
    ensureIsUnsignedInt(T);

    const BIT_SIZE = @bitSizeOf(T);

    const BIT_MASKS: [BIT_SIZE]T = blk: {
        var result: [BIT_SIZE]T = undefined;

        for (0..BIT_SIZE) |i| {
            result[i] = 1 << i;
        }

        break :blk result;
    };

    const INVERTED_MASKS: [BIT_SIZE]T = blk: {
        var result: [BIT_SIZE]T = undefined;

        for (0..BIT_SIZE) |i| {
            result[i] = ~BIT_MASKS[i];
        }

        break :blk result;
    };

    return struct {
        bits: T = 0,

        const len = BIT_SIZE;

        const Self = @This();

        /// Get the value of the bit at the given index (index counts from the least significant bit)
        pub fn get(self: Self, index: usize) !u1 {
            if (index >= BIT_SIZE) {
                return error.IndexOutOfBounds;
            }

            return if (self.bits & BIT_MASKS[index] != 0) 1 else 0;
        }

        /// Set the value of the bit at the given index (index counts from the least significant bit)
        pub fn set(self: *Self, index: usize, value: u1) !void {
            if (index >= BIT_SIZE) {
                return error.IndexOutOfBounds;
            }

            if (value == 0) {
                self.bits &= INVERTED_MASKS[index];
            } else {
                self.bits |= BIT_MASKS[index];
            }
        }

        /// Set the value of the bit at the given index to 1
        pub fn setOn(self: *Self, index: usize) !void {
            if (index >= BIT_SIZE) {
                return error.IndexOutOfBounds;
            }

            self.bits |= BIT_MASKS[index];
        }

        /// Set all bits to 0
        pub fn clear(self: *Self) void {
            self.bits = 0;
        }

        /// Check if all bits are 0
        pub fn isEmpty(self: Self) bool {
            return self.bits == 0;
        }

        /// Return a bit iterator
        pub fn iter(self: Self) BitIterator(T) {
            return BitIterator(T).init(self.bits);
        }
    };
}

const BitArray32 = BitArray(u32);
const BitArray64 = BitArray(u64);

test "BitArray" {
    var bitarray = BitArray32{};
    try std.testing.expectEqual(0, bitarray.bits);

    try bitarray.set(0, 1);
    try std.testing.expectEqual(1, try bitarray.get(0));

    try bitarray.set(31, 1);
    try std.testing.expectEqual(1, try bitarray.get(31));
    try std.testing.expectEqual(0b10000000000000000000000000000001, bitarray.bits);

    try bitarray.set(0, 0);
    try std.testing.expectEqual(0, try bitarray.get(0));
    try std.testing.expectEqual(0b10000000000000000000000000000000, bitarray.bits);
}

test "BitIterator" {
    var bitarray = BitArray32{ .bits = 0b101 };
    var iterator = bitarray.iter();

    for (0..BitArray32.len) |index| {
        try std.testing.expectEqual(try bitarray.get(index), iterator.next());
    }

    var index: usize = 0;
    var iterator2 = bitarray.iter();
    while (iterator2.next()) |value| {
        try std.testing.expectEqual(try bitarray.get(index), value);
        index += 1;
    }
}
