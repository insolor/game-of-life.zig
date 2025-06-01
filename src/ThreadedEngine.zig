const std = @import("std");
const testing = std.testing;
const object_library = @import("object_library.zig");
const Field = @import("Field.zig");
const Block = Field.BlockType;
const Engine = @import("Engine.zig");

const AutoHashMap = std.AutoHashMap;
const Pair = struct { isize, isize };

allocator: std.mem.Allocator,
field: Field,

const Self = @This();

/// Initialize engine object
pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .field = Field.init(allocator),
    };
}

/// Deinitialize engine object
pub fn deinit(self: *Self) void {
    self.field.deinit();
}

/// Calculate next state of one block
fn calculateBlockNextState(allocator: std.mem.Allocator, block_coords: struct { isize, isize }, field: Field) !?*Block {
    var new_block = try Block.init(allocator);
    const block_x, const block_y = block_coords;
    const field_x = block_x * Field.get_block_size();
    const field_y = block_y * Field.get_block_size();

    var x: usize = 0;
    while (x <= Field.get_block_size()) : (x += 1) {
        var y: usize = @intCast(field_y);
        while (y <= Field.get_block_size()) : (y += 1) {
            const new_cell_state = try Engine.calculateCellNextState(
                field,
                field_x + @as(isize, @intCast(x)),
                field_y + @as(isize, @intCast(y)),
            );
            if (new_cell_state == 1) {
                try new_block.setOn(x, y);
            }
        }
    }

    if (new_block.isEmpty()) {
        new_block.deinit();
        return null;
    }

    return new_block;
}

/// Calculate next state of the entire field
fn calculateFieldNextState(field: Field) !Field {
    var result = Field.init(field.allocator);

    var calculated_cells = AutoHashMap(Pair, void).init(field.allocator);
    defer calculated_cells.deinit();

    var block_coords_iterator = field.blocks.keyIterator();

    while (block_coords_iterator.next()) |block_coords| {
        const optional_block = try calculateBlockNextState(field.allocator, block_coords.*, field);
        if (optional_block) |block| {
            try result.blocks.put(block_coords.*, block);
        }
        // TODO: calculate outer edge cells
    }

    return result;
}

pub fn nextFieldState(self: *Self) !void {
    const next_state = try calculateFieldNextState(self.field);
    self.field.deinit();
    self.field = next_state;
}

test "Calculate next field state (glider)" {
    var field = Field.init(testing.allocator);
    defer field.deinit();

    // Initial state of the field ("glider"):
    // 010
    // 001
    // 111

    try field.putObject(object_library.GLIDER, 0, 0);

    var result = try calculateFieldNextState(field);
    defer result.deinit();
    try testing.expect(!result.isEmpty());
    // Expected state here:
    // 000
    // 101
    // 011
    // 010

    // After clearing cells that are expected to be 1 the field should be empty:
    try result.setOff(0, 1);
    try result.setOff(2, 1);
    try result.setOff(1, 2);
    try result.setOff(2, 2);
    try result.setOff(1, 3);

    try testing.expect(result.isEmpty());
}

test "Calculate next field state (blinker)" {
    var field = Field.init(testing.allocator);
    defer field.deinit();

    // Initial state:
    // 111

    try field.putObject(object_library.BLINKER, 0, 0);

    var result = try calculateFieldNextState(field);
    defer result.deinit();
    try testing.expect(!result.isEmpty());

    // Expected state:
    // 010 - a block higher of the original one
    // ---
    // 010
    // 010

    try testing.expectEqual(2, result.blocks.count());

    try result.setOff(1, -1);
    try result.setOff(1, 0);
    try result.setOff(1, 1);
    try testing.expect(result.isEmpty());
}
