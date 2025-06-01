const std = @import("std");
const testing = std.testing;
const object_library = @import("object_library.zig");
const Field = @import("Field.zig");

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

/// Calculate next state of a single cell of the field based on count of the cell's neighbours
fn calculateCellNextState(field: Field, x: isize, y: isize) !u1 {
    const current_state = try field.get(x, y);
    var sum: u8 = 0;

    var i = x - 1;
    while (i <= x + 1) : (i += 1) {
        var j = y - 1;
        while (j <= y + 1) : (j += 1) {
            sum += try field.get(i, j);
        }
    }

    sum -= current_state;

    if (current_state == 1) {
        return if (sum == 2 or sum == 3) 1 else 0;
    } else {
        return if (sum == 3) 1 else 0;
    }
}

/// Calculate next state of the entire field
fn calculateFieldNextState(field: Field) !Field {
    var result = Field.init(field.allocator);

    var calculated_cells = AutoHashMap(Pair, void).init(field.allocator);
    defer calculated_cells.deinit();

    var block_coords_iterator = field.blocks.keyIterator();

    while (block_coords_iterator.next()) |block_coords| {
        const block_x, const block_y = block_coords.*;
        const field_x = block_x * Field.get_block_size();
        const field_y = block_y * Field.get_block_size();

        var x = field_x - 1;
        while (x <= field_x + Field.get_block_size() + 1) : (x += 1) {
            var y = field_y - 1;
            while (y <= field_y + Field.get_block_size() + 1) : (y += 1) {
                if (calculated_cells.contains(.{ x, y })) {
                    continue;
                }

                const new_cell_state = try calculateCellNextState(field, x, y);
                if (new_cell_state == 1) {
                    try result.setOn(x, y);
                }
                try calculated_cells.put(.{ x, y }, {});
            }
        }
    }

    return result;
}

pub fn nextFieldState(self: *Self) !void {
    const next_state = try calculateFieldNextState(self.field);
    self.field.deinit();
    self.field = next_state;
}

test "Calculate next cell state" {
    var field = Field.init(testing.allocator);
    defer field.deinit();

    try field.setOn(0, 0);
    try testing.expectEqual(0, try calculateCellNextState(field, 0, 0));

    // 10
    // 11

    try field.setOn(0, 1);
    try field.setOn(1, 1);
    try testing.expectEqual(1, try calculateCellNextState(field, 0, 0));
    try testing.expectEqual(1, try calculateCellNextState(field, 1, 0));
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
