const std = @import("std");
const bitarray = @import("bitarray.zig");
const AutoHashMap = std.AutoHashMap;
const Tuple = std.meta.Tuple;

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

        /// Clear the block
        fn clear(self: *Self) void {
            for (&self.rows) |*value| {
                value.clear();
            }
        }

        /// Set the value of a cell
        fn set(self: *Self, row: usize, col: usize, value: u1) !void {
            try self.rows[row].set(col, value);
        }

        /// Get the value of a cell
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
    };
}

const Pair = Tuple(&[_]type{ isize, isize });

pub const Field = struct {
    const BLOCK_ROW_TYPE = u32;
    const BLOCK_SIZE = @bitSizeOf(BLOCK_ROW_TYPE);

    const BlockType = Block(BLOCK_ROW_TYPE);

    /// A hasmap representing a sparse 2D array of blocks
    blocks: AutoHashMap(Pair, *BlockType),

    allocator: std.mem.Allocator,

    const Self = @This();

    fn init(allocator: std.mem.Allocator) Field {
        return Field{
            .blocks = AutoHashMap(Pair, *BlockType).init(allocator),
            .allocator = allocator,
        };
    }

    fn deinit(self: *Field) void {
        var value_iterator = self.blocks.valueIterator();
        while (value_iterator.next()) |block| {
            block.*.deinit();
        }
        self.blocks.deinit();
    }

    const BlockCoords = struct {
        /// x and y coordinates of the block in the hashmap
        block_x: isize,
        block_y: isize,
        /// x and ycoordinates of the cell in the block
        local_x: usize,
        local_y: usize,
    };

    /// Convert global coordinates of a cell in the field to block coordinates
    fn convert_to_block_coords(x: isize, y: isize) BlockCoords {
        return .{
            .block_x = @divFloor(x, BLOCK_SIZE),
            .block_y = @divFloor(x, BLOCK_SIZE),
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
};

test "Block" {
    var block = Block(u32){};
    try std.testing.expectEqual(32, block.rows.len);

    block.clear();
    try std.testing.expect(block.isEmpty());

    try block.set(0, 0, 1);
    try std.testing.expectEqual(1, try block.get(0, 0));
    try std.testing.expect(!block.isEmpty());

    try block.set(0, 0, 0);
    try std.testing.expectEqual(0, try block.get(0, 0));
    try std.testing.expect(block.isEmpty());
}

test "Field" {
    var field = Field.init(std.testing.allocator);
    defer field.deinit();

    field.set(0, 0, 1);
    try std.testing.expectEqual(1, field.get(0, 0));

    field.set(0, 0, 0);
    try std.testing.expectEqual(0, field.get(0, 0));

    const block: *Block(u32) = field.blocks.get(.{ 0, 0 }) orelse unreachable;
    try std.testing.expect(block.isEmpty());

    field.set(-1, -1, 1);
    try std.testing.expectEqual(1, field.get(-1, -1));
}
