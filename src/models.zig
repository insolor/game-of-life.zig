const std = @import("std");
const bitarray = @import("bitarray.zig");
const testing_utils = @import("testing_utils.zig");
const testing = std.testing;
const AutoHashMap = std.AutoHashMap;
const Tuple = std.meta.Tuple;
const expectEqualStructs = testing_utils.expectEqualStructs;

const BitArray = bitarray.BitArray;

/// A square block of cells. T should be an unsigned integer type.
fn Block(comptime T: type) type {
    return struct {
        const BLOCK_SIZE = @bitSizeOf(T);

        /// Array of rows, each row is represented as a bitarray (an unsigned integer internally)
        rows: [BLOCK_SIZE]BitArray(T) = undefined,

        allocator: std.mem.Allocator = undefined,

        const Self = @This();

        fn init(allocator: std.mem.Allocator) *Self {
            var self = allocator.create(Self) catch unreachable;
            self.allocator = allocator;
            self.clear();
            return self;
        }

        fn deinit(self: *Self) void {
            self.allocator.destroy(self);
        }

        /// Set all cells in the block to 0
        fn clear(self: *Self) void {
            for (&self.rows) |*value| {
                value.clear();
            }
        }

        /// Set the value of a cell in the block
        fn set(self: *Self, row: usize, col: usize, value: u1) !void {
            try self.rows[row].set(col, value);
        }

        /// Set the cell's value to 1
        fn setOn(self: *Self, row: usize, col: usize) !void {
            try self.rows[row].setOn(col);
        }

        /// Get the value of a cell in the block
        fn get(self: Self, row: usize, col: usize) !u1 {
            return try self.rows[row].get(col);
        }

        /// Check if the block is empty
        fn isEmpty(self: Self) bool {
            for (self.rows) |row| {
                if (!row.isEmpty()) {
                    return false;
                }
            }
            return true;
        }

        pub fn debug_print(self: Self) void {
            for (0..BLOCK_SIZE) |y| {
                for (0..BLOCK_SIZE) |x| {
                    const value = self.get(x, y) catch unreachable;
                    std.debug.print("{s}", .{if (value == 0) "." else "#"});
                }
                std.debug.print("\n", .{});
            }
        }
    };
}

pub const Pair = Tuple(&[_]type{ isize, isize });

pub const Field = struct {
    const BLOCK_ROW_TYPE = u32;
    const BLOCK_SIZE = @bitSizeOf(BLOCK_ROW_TYPE);

    const BlockType = Block(BLOCK_ROW_TYPE);

    /// A hasmap representing a sparse 2D array of blocks
    blocks: AutoHashMap(Pair, *BlockType),

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Field {
        return Field{
            .blocks = AutoHashMap(Pair, *BlockType).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Field) void {
        var value_iterator = self.blocks.valueIterator();
        while (value_iterator.next()) |block| {
            block.*.deinit();
        }
        self.blocks.deinit();
    }

    const BlockCoords = struct {
        /// x coordinate of the block in the hashmap
        block_x: isize,
        /// y coordinate of the block in the hashmap
        block_y: isize,
        /// x coordinate of the cell in the block
        local_x: usize,
        /// y coordinate of the cell in the block
        local_y: usize,
    };

    /// Convert global coordinates of a cell in the field to block coordinates
    fn convert_to_block_coords(x: isize, y: isize) BlockCoords {
        return .{
            .block_x = @divFloor(x, BLOCK_SIZE),
            .block_y = @divFloor(y, BLOCK_SIZE),
            .local_x = @intCast(@mod(x, BLOCK_SIZE)),
            .local_y = @intCast(@mod(y, BLOCK_SIZE)),
        };
    }

    /// Set a value to a cell with the given coordinates
    pub fn set(self: *Self, x: isize, y: isize, value: u1) void {
        const coords = convert_to_block_coords(x, y);
        var block: ?*BlockType = self.blocks.get(.{ coords.block_x, coords.block_y });
        if (block == null) {
            if (value == 0) {
                return;
            }

            block = BlockType.init(self.allocator);
            self.blocks.put(.{ coords.block_x, coords.block_y }, block.?) catch unreachable;
        }

        block.?.set(coords.local_x, coords.local_y, value) catch unreachable;
    }

    /// Set the cell's value to 1
    pub fn setOn(self: *Self, x: isize, y: isize) void {
        const coords = convert_to_block_coords(x, y);
        var block: ?*BlockType = self.blocks.get(.{ coords.block_x, coords.block_y });
        if (block == null) {
            block = BlockType.init(self.allocator);
            self.blocks.put(.{ coords.block_x, coords.block_y }, block.?) catch unreachable;
        }

        block.?.setOn(coords.local_x, coords.local_y) catch unreachable;
    }

    /// Get the value of a cell with the given coordinates
    pub fn get(self: Self, x: isize, y: isize) u1 {
        const coords = convert_to_block_coords(x, y);
        const block = self.blocks.get(.{ coords.block_x, coords.block_y }) orelse return 0;
        return block.get(coords.local_x, coords.local_y) catch unreachable;
    }

    /// Clear the field
    pub fn clear(self: *Self) void {
        for (self.blocks.valueIterator()) |block| {
            block.deinit();
        }
        self.blocks.clearRetainingCapacity();
    }

    /// Check if the field is empty
    pub fn isEmpty(self: Self) bool {
        var block_iterator = self.blocks.valueIterator();
        while (block_iterator.next()) |block| {
            if (!block.*.isEmpty()) {
                return false;
            }
        }
        return true;
    }

    /// Get the size of a block
    pub inline fn get_block_size(self: Self) usize {
        _ = self;
        return BLOCK_SIZE;
    }
};

test "Block" {
    var block = Block(u32){};
    try testing.expectEqual(32, block.rows.len);

    block.clear();
    try testing.expect(block.isEmpty());

    try block.set(0, 0, 1);
    try testing.expectEqual(1, try block.get(0, 0));
    try testing.expect(!block.isEmpty());

    try block.set(0, 0, 0);
    try testing.expectEqual(0, try block.get(0, 0));
    try testing.expect(block.isEmpty());
}

test "convert_to_block_coords" {
    try expectEqualStructs(
        .{ .block_x = 0, .block_y = 0, .local_x = 0, .local_y = 0 },
        Field.convert_to_block_coords(0, 0),
    );

    try expectEqualStructs(
        .{ .block_x = 0, .block_y = -1, .local_x = 0, .local_y = 31 },
        Field.convert_to_block_coords(0, -1),
    );

    try expectEqualStructs(
        .{ .block_x = -1, .block_y = 0, .local_x = 31, .local_y = 0 },
        Field.convert_to_block_coords(-1, 0),
    );

    try expectEqualStructs(
        .{ .block_x = -1, .block_y = -1, .local_x = 31, .local_y = 31 },
        Field.convert_to_block_coords(-1, -1),
    );
}

test "Field" {
    var field = Field.init(testing.allocator);
    defer field.deinit();

    field.set(0, 0, 1);
    try testing.expectEqual(1, field.get(0, 0));

    field.set(0, 0, 0);
    try testing.expectEqual(0, field.get(0, 0));

    const block: *Block(u32) = field.blocks.get(.{ 0, 0 }) orelse unreachable;
    try testing.expect(block.isEmpty());

    field.set(-1, -1, 1);
    try testing.expectEqual(1, field.get(-1, -1));
}
