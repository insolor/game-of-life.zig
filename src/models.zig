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
        fn init(allocator: std.mem.Allocator) !*Self {
            var self = try allocator.create(Self);
            self.allocator = allocator;
            self.clear();
            return self;
        }

        /// Deinitialize the block
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
        fn set(self: *Self, x: usize, y: usize, value: u1) !void {
            try self.rows[y].set(x, value);
        }

        /// Set the cell's value to 1
        fn setOn(self: *Self, x: usize, y: usize) !void {
            try self.rows[y].setOn(x);
        }

        /// Get the value of a cell in the block
        fn get(self: Self, x: usize, y: usize) !u1 {
            return try self.rows[y].get(x);
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

/// A pair of signed integer values
pub const Pair = struct { isize, isize };

/// A class represening the game field
pub const Field = struct {
    const BLOCK_ROW_TYPE = u32;
    const BLOCK_SIZE = @bitSizeOf(BLOCK_ROW_TYPE);

    const BlockType = Block(BLOCK_ROW_TYPE);

    /// A hasmap representing a sparse 2D array of blocks
    blocks: AutoHashMap(Pair, *BlockType),

    allocator: std.mem.Allocator,

    const Self = @This();

    /// Initialize a new field
    pub fn init(allocator: std.mem.Allocator) Field {
        return Field{
            .blocks = AutoHashMap(Pair, *BlockType).init(allocator),
            .allocator = allocator,
        };
    }

    /// Deinitialize the field
    pub fn deinit(self: *Field) void {
        var value_iterator = self.blocks.valueIterator();
        while (value_iterator.next()) |block| {
            block.*.deinit();
        }
        self.blocks.deinit();
    }

    /// Coordinates of a block in the field and a cell in the block
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
    fn convertToBlockCoords(x: isize, y: isize) BlockCoords {
        return .{
            .block_x = @divFloor(x, BLOCK_SIZE),
            .block_y = @divFloor(y, BLOCK_SIZE),
            .local_x = @intCast(@mod(x, BLOCK_SIZE)),
            .local_y = @intCast(@mod(y, BLOCK_SIZE)),
        };
    }

    /// Set a value to a cell with the given coordinates
    pub fn set(self: *Self, x: isize, y: isize, value: u1) !void {
        const coords = convertToBlockCoords(x, y);
        var block: ?*BlockType = self.blocks.get(.{ coords.block_x, coords.block_y });
        if (block == null) {
            if (value == 0) {
                return;
            }

            block = try BlockType.init(self.allocator);
            try self.blocks.put(.{ coords.block_x, coords.block_y }, block.?);
        }

        try block.?.set(coords.local_x, coords.local_y, value);
    }

    /// Set the cell's value to 1
    pub fn setOn(self: *Self, x: isize, y: isize) !void {
        const coords = convertToBlockCoords(x, y);
        var block: ?*BlockType = self.blocks.get(.{ coords.block_x, coords.block_y });
        if (block == null) {
            block = try BlockType.init(self.allocator);
            try self.blocks.put(.{ coords.block_x, coords.block_y }, block.?);
        }

        try block.?.setOn(coords.local_x, coords.local_y);
    }

    /// Get the value of a cell with the given coordinates
    pub fn get(self: Self, x: isize, y: isize) !u1 {
        const coords = convertToBlockCoords(x, y);
        const block = self.blocks.get(.{ coords.block_x, coords.block_y }) orelse return 0;
        return try block.get(coords.local_x, coords.local_y);
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
    pub inline fn get_block_size() u8 {
        return BLOCK_SIZE;
    }

    pub fn putObject(self: *Field, obj: []const u8, x: isize, y: isize) !void {
        var row_iterator = std.mem.splitScalar(u8, obj, '\n');
        var i: isize = 0;
        while (row_iterator.next()) |row| : (i += 1) {
            var j: isize = 0;
            for (row) |char| {
                if (char != ' ') {
                    try self.setOn(x + @as(isize, j), y + i);
                }
                j += 1;
            }
        }
    }
};

test "Block" {
    var block = try Block(u32).init(testing.allocator);
    defer block.deinit();

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
        Field.convertToBlockCoords(0, 0),
    );

    try expectEqualStructs(
        .{ .block_x = 0, .block_y = -1, .local_x = 0, .local_y = 31 },
        Field.convertToBlockCoords(0, -1),
    );

    try expectEqualStructs(
        .{ .block_x = -1, .block_y = 0, .local_x = 31, .local_y = 0 },
        Field.convertToBlockCoords(-1, 0),
    );

    try expectEqualStructs(
        .{ .block_x = -1, .block_y = -1, .local_x = 31, .local_y = 31 },
        Field.convertToBlockCoords(-1, -1),
    );
}

test "Field" {
    var field = Field.init(testing.allocator);
    defer field.deinit();

    try field.set(0, 0, 1);
    try testing.expectEqual(1, try field.get(0, 0));

    try field.set(0, 0, 0);
    try testing.expectEqual(0, try field.get(0, 0));

    const block: *Block(u32) = field.blocks.get(.{ 0, 0 }) orelse unreachable;
    try testing.expect(block.isEmpty());

    try field.set(-1, -1, 1);
    try testing.expectEqual(1, try field.get(-1, -1));
}
