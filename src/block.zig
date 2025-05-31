const std = @import("std");
const bitarray = @import("bitarray.zig");
const testing_utils = @import("testing_utils.zig");
const testing = std.testing;
const AutoHashMap = std.AutoHashMap;
const expectEqualStructs = testing_utils.expectEqualStructs;

const BitArray = bitarray.BitArray;

/// A square block of cells. T should be an unsigned integer type.
pub fn Block(comptime T: type) type {
    return struct {
        const BLOCK_SIZE = @bitSizeOf(T);

        /// Array of rows, each row is represented as a bitarray (an unsigned integer internally)
        rows: [BLOCK_SIZE]BitArray(T),

        allocator: std.mem.Allocator,

        const Self = @This();

        /// Initialize a new block
        pub fn init(allocator: std.mem.Allocator) !*Self {
            var self = try allocator.create(Self);
            self.allocator = allocator;
            self.clear();
            return self;
        }

        /// Deinitialize the block
        pub fn deinit(self: *Self) void {
            self.allocator.destroy(self);
        }

        /// Set all cells in the block to 0
        pub fn clear(self: *Self) void {
            for (&self.rows) |*value| {
                value.clear();
            }
        }

        /// Set the cell's value to 1
        pub fn setOn(self: *Self, x: usize, y: usize) !void {
            try self.rows[y].setOn(x);
        }

        /// Set the cell's value to 0
        pub fn setOff(self: *Self, x: usize, y: usize) !void {
            try self.rows[y].setOff(x);
        }

        /// Get the value of a cell in the block
        pub fn get(self: Self, x: usize, y: usize) !u1 {
            return try self.rows[y].get(x);
        }

        /// Check if the block is empty
        pub fn isEmpty(self: Self) bool {
            for (self.rows) |row| {
                if (!row.isEmpty()) {
                    return false;
                }
            }
            return true;
        }

        /// Print contents of the block to the terminal
        pub fn debugPrint(self: Self) !void {
            for (0..BLOCK_SIZE) |y| {
                for (0..BLOCK_SIZE) |x| {
                    const value = try self.get(x, y);
                    std.debug.print("{s}", .{if (value == 0) "." else "#"});
                }
                std.debug.print("\n", .{});
            }
        }
    };
}

test "Block" {
    var block = try Block(u32).init(testing.allocator);
    defer block.deinit();

    try testing.expectEqual(32, block.rows.len);

    block.clear();
    try testing.expect(block.isEmpty());

    try block.setOn(0, 0);
    try testing.expectEqual(1, try block.get(0, 0));
    try testing.expect(!block.isEmpty());

    try block.setOff(0, 0);
    try testing.expectEqual(0, try block.get(0, 0));
    try testing.expect(block.isEmpty());
}
