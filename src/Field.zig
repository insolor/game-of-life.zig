//! A class represening the game field
const std = @import("std");
const AutoHashMap = std.AutoHashMap;
const Block = @import("block.zig").Block;
const testing = std.testing;
const testing_utils = @import("testing_utils.zig");
const expectEqualStructs = testing_utils.expectEqualStructs;

/// A pair of signed integer values
const Pair = struct { isize, isize };

const BLOCK_ROW_TYPE = u32;
const BLOCK_SIZE = @bitSizeOf(BLOCK_ROW_TYPE);

const BlockType = Block(BLOCK_ROW_TYPE);

/// A hasmap representing a sparse 2D array of blocks
blocks: AutoHashMap(Pair, *BlockType),

allocator: std.mem.Allocator,

const Self = @This();

/// Initialize a new field
pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .blocks = AutoHashMap(Pair, *BlockType).init(allocator),
        .allocator = allocator,
    };
}

/// Deinitialize the field
pub fn deinit(self: *Self) void {
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

/// Set the cell's value to 0
pub fn setOff(self: *Self, x: isize, y: isize) !void {
    const coords = convertToBlockCoords(x, y);
    var block: ?*BlockType = self.blocks.get(.{ coords.block_x, coords.block_y });
    if (block == null) {
        return;
    }

    try block.?.setOff(coords.local_x, coords.local_y);
}

/// Get the value of a cell with the given coordinates
pub fn get(self: Self, x: isize, y: isize) !u1 {
    const coords = convertToBlockCoords(x, y);
    const block = self.blocks.get(.{ coords.block_x, coords.block_y }) orelse return 0;
    return try block.get(coords.local_x, coords.local_y);
}

/// Clear the field
pub fn clear(self: *Self) void {
    var iterator = self.blocks.valueIterator();
    while (iterator.next()) |block| {
        block.*.deinit();
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

pub fn putObject(self: *Self, obj: []const u8, x: isize, y: isize) !void {
    var row_iterator = std.mem.splitScalar(u8, obj, '\n');
    var i: isize = 0;
    while (row_iterator.next()) |row| : (i += 1) {
        for (row, 0..) |char, j| {
            if (char != ' ') {
                try self.setOn(x + @as(isize, @intCast(j)), y + i);
            }
        }
    }
}

test "Field" {
    var field = Self.init(testing.allocator);
    defer field.deinit();

    try field.setOn(0, 0);
    try testing.expectEqual(1, try field.get(0, 0));

    try field.setOff(0, 0);
    try testing.expectEqual(0, try field.get(0, 0));

    const block: *Block(u32) = field.blocks.get(.{ 0, 0 }) orelse unreachable;
    try testing.expect(block.isEmpty());

    try field.setOn(-1, -1);
    try testing.expectEqual(1, try field.get(-1, -1));
}

test "convert_to_block_coords" {
    try expectEqualStructs(
        .{ .block_x = 0, .block_y = 0, .local_x = 0, .local_y = 0 },
        Self.convertToBlockCoords(0, 0),
    );

    try expectEqualStructs(
        .{ .block_x = 0, .block_y = -1, .local_x = 0, .local_y = 31 },
        Self.convertToBlockCoords(0, -1),
    );

    try expectEqualStructs(
        .{ .block_x = -1, .block_y = 0, .local_x = 31, .local_y = 0 },
        Self.convertToBlockCoords(-1, 0),
    );

    try expectEqualStructs(
        .{ .block_x = -1, .block_y = -1, .local_x = 31, .local_y = 31 },
        Self.convertToBlockCoords(-1, -1),
    );
}
