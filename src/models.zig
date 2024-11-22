const std = @import("std");
const bitarray = @import("bitarray.zig");
const AutoHashMap = std.AutoHashMap;
const Tuple = std.meta.Tuple;

const BitArray = bitarray.BitArray;

fn Block(comptime T: type) type {
    return struct {
        const BLOCK_SIZE = @sizeOf(T);

        rows: [BLOCK_SIZE]BitArray(T) = blk: {
            var result: [BLOCK_SIZE]BitArray(T) = undefined;

            var i: u32 = 0;
            while (i < BLOCK_SIZE) : (i += 1) {
                result[i] = BitArray(T){};
            }

            break :blk result;
        },

        const Self = @This();

        fn set(self: *Self, row: usize, col: usize, value: u1) !void {
            try self.rows[row].set(col, value);
        }

        fn get(self: Self, row: usize, col: usize) !u1 {
            return try self.rows[row].get(col);
        }

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

const Pair = Tuple(&[_]type{ usize, usize });

pub const Field = struct {
    blocks: AutoHashMap(Pair, *Block(u32)),
    allocator: std.mem.Allocator,

    const Self = @This();

    fn init(allocator: std.mem.Allocator) Field {
        return Field{
            .blocks = AutoHashMap(Pair, *Block(u32)).init(allocator),
            .allocator = allocator,
        };
    }

    fn deinit(self: *Field) void {
        var value_iterator = self.blocks.valueIterator();
        while (value_iterator.next()) |block| {
            self.allocator.destroy(block.*);
        }
        self.allocator.destroy(self.blocks);
    }

    const BlockCoords = struct {
        block_x: usize,
        block_y: usize,
        local_x: usize,
        local_y: usize,
    };

    fn convert_to_block_coords(x: usize, y: usize) BlockCoords {
        return .{
            .block_x = x / 32,
            .block_y = y / 32,
            .local_x = x % 32,
            .local_y = y % 32,
        };
    }

    pub fn set(self: *Self, x: usize, y: usize, value: u1) !void {
        const coords = convert_to_block_coords(x, y);
        var block: ?*Block(u32) = self.blocks.get(.{ coords.block_x, coords.block_y });
        if (block == null) {
            if (value == 0) {
                return;
            }

            block = self.allocator.create(Block(u32)) catch unreachable;
            try self.blocks.put(.{ coords.block_x, coords.block_y }, block.?);
        }

        try block.?.set(coords.local_x, coords.local_y, value);
    }

    pub fn get(self: Self, x: usize, y: usize) !u1 {
        const coords = convert_to_block_coords(x, y);
        const block = self.blocks.get(.{ coords.block_x, coords.block_y }) orelse return 0;
        return try block.get(coords.local_x, coords.local_y);
    }

    pub fn clear(self: *Self) void {
        for (self.blocks.valueIterator()) |block| {
            block.deinit();
        }
        self.blocks.clearRetainingCapacity();
    }
};

test "Block" {
    var block = Block(u32){};

    try std.testing.expect(block.isEmpty());
    try block.set(0, 0, 1);
    try std.testing.expectEqual(1, try block.get(0, 0));
    try std.testing.expect(!block.isEmpty());
}

test "Field" {
    var field = Field.init(std.testing.allocator);
    defer field.deinit();

    try field.set(0, 0, 1);
    try std.testing.expectEqual(1, try field.get(0, 0));

    try field.set(0, 0, 0);
    try std.testing.expectEqual(0, try field.get(0, 0));

    const block: *Block(u32) = field.blocks.get(.{ 0, 0 }) orelse unreachable;
    try std.testing.expect(block.isEmpty());
}
