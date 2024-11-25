const std = @import("std");
const models = @import("models.zig");

const AutoHashMap = std.AutoHashMap;
const Field = models.Field;
const Block = models.Block;
const Pair = models.Pair;

fn calculate_cell_next_state(self: Field, x: isize, y: isize) u1 {
    const current_state = self.get(x, y);
    var sum: i8 = 0;
    sum -= current_state;

    var i = x - 1;
    while (i <= x + 1) : (i += 1) {
        var j = y - 1;
        while (j <= y + 1) : (j += 1) {
            sum += self.get(i, j);
        }
    }

    if (current_state == 1) {
        return if (sum == 2 or sum == 3) 1 else 0;
    } else {
        return if (sum == 3) 1 else 0;
    }
}

fn calculate_field_next_state(field: Field) Field {
    var result = Field.init(field.allocator);

    var calculated_cells = AutoHashMap(Pair, void).init(field.allocator);
    defer calculated_cells.deinit();

    var block_coords_iterator = field.blocks.keyIterator();

    while (block_coords_iterator.next()) |block_coords| {
        const block_x, const block_y = block_coords.*;
        const field_x = block_x * field.get_block_size();
        const field_y = block_y * field.get_block_size();

        var x = field_x - 1;
        while (x <= field_x + field.get_block_size() + 1) : (x += 1) {
            var y = field_y - 1;
            while (y <= field_y + field.get_block_size() + 1) : (y += 1) {
                if (calculated_cells.contains(.{ x, y })) {
                    continue;
                }

                const new_cell_state = calculate_cell_next_state(field, x, y);
                if (new_cell_state == 1) {
                    result.setOn(x, y);
                }
                calculated_cells.put(.{ x, y }, {}) catch unreachable;
            }
        }
    }

    return result;
}

test "Calculate next cell state" {
    var field = Field.init(std.testing.allocator);
    defer field.deinit();

    field.setOn(0, 0);
    try std.testing.expectEqual(0, calculate_cell_next_state(field, 0, 0));

    // 10
    // 11

    field.setOn(0, 1);
    field.setOn(1, 1);
    try std.testing.expectEqual(1, calculate_cell_next_state(field, 0, 0));
    try std.testing.expectEqual(1, calculate_cell_next_state(field, 1, 0));
}

test "Calculate next field state (glider)" {
    var field = Field.init(std.testing.allocator);
    defer field.deinit();

    // Initial state of the field ("glider"):
    // 010
    // 001
    // 111

    field.setOn(1, 0);
    field.setOn(2, 1);
    field.setOn(0, 2);
    field.setOn(1, 2);
    field.setOn(2, 2);

    var result = calculate_field_next_state(field);
    defer result.deinit();
    try std.testing.expect(!result.isEmpty());
    // Expected state here:
    // 000
    // 101
    // 011
    // 010

    // After clearing cells that are expected to be 1 the field should be empty:
    result.set(0, 1, 0);
    result.set(2, 1, 0);
    result.set(1, 2, 0);
    result.set(2, 2, 0);
    result.set(1, 3, 0);

    try std.testing.expect(result.isEmpty());
}

test "Calculate next field state (blinker)" {
    var field = Field.init(std.testing.allocator);
    defer field.deinit();

    // Initial state:
    // 111

    field.setOn(0, 0);
    field.setOn(1, 0);
    field.setOn(2, 0);

    var result = calculate_field_next_state(field);
    defer result.deinit();
    try std.testing.expect(!result.isEmpty());

    // Expected state:
    // 010 - a block higher of the original one
    // ---
    // 010
    // 010

    try std.testing.expectEqual(2, result.blocks.count());

    result.set(1, -1, 0);
    result.set(1, 0, 0);
    result.set(1, 1, 0);
    try std.testing.expect(result.isEmpty());
}
