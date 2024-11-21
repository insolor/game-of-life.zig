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
    };
}

pub const Field = struct {
    blocks: AutoHashMap(Tuple(&[_]type{ usize, usize }), Block(u32)),

    const Self = @This();

    fn init(allocator: std.mem.Allocator) Field {
        return Field{
            .blocks = AutoHashMap(Tuple(&[_]type{ usize, usize }), Block(u32)).init(allocator),
        };
    }

    fn deinit(self: Field) void {
        for (self.blocks.valueIterator()) |block| {
            block.deinit();
        }
        self.blocks.deinit();
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

    fn set(self: *Self, x: usize, y: usize, value: u1) !void {
        const coords = self.convert_to_block_coords(x, y);
        var block: ?Block = self.blocks.get(.{ coords.block_x, coords.block_y });
        if (block == null) {
            if (value == 0) {
                return;
            }
            
            block = Block(u32){};
            try self.blocks.put(.{ coords.block_x, coords.block_y }, block.?);
        }
        
        try block.?.set(coords.local_x, coords.local_y, value);
    }
    
    fn get(self: Self, x: usize, y: usize) !u1 {
        const coords = self.convert_to_block_coords(x, y);
        const block = self.blocks.get(.{ coords.block_x, coords.block_y }) orelse return 0;
        return try block.get(coords.local_x, coords.local_y);
    }
    
    fn clear(self: *Self) void {
        for (self.blocks.valueIterator()) |block| {
            block.deinit();
        }
        self.blocks.clearRetainingCapacity();
    }
};
