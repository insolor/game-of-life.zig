const rl = @import("raylib");
const std = @import("std");

const models = @import("models.zig");
const Pair = models.Pair;
const Block = models.Block;
const Field = models.Field;

const DRAW_COLOR = rl.Color.white;

inline fn float32FromInt(value: anytype) f32 {
    return @floatFromInt(value);
}

pub const DisplayParams = struct {
    width: usize,
    height: usize,
    scale_factor: u8 = 4,
    pixel_offset_x: isize = 0,
    pixel_offset_y: isize = 0,

    const SCALING_BASE = 2;
    const Self = @This();

    pub fn scaleAt(self: *Self, mouse_x: isize, mouse_y: isize, new_scale_factor: u8) void {
        const old_scale = self.getIntScale();
        self.scale_factor = new_scale_factor;
        const new_scale = self.getIntScale();
        self.pixel_offset_x = @divFloor((self.pixel_offset_x - mouse_x) * new_scale, old_scale) + mouse_x;
        self.pixel_offset_y = @divFloor((self.pixel_offset_y - mouse_y) * new_scale, old_scale) + mouse_y;
    }

    pub fn screenToFieldsCoords(self: Self, screen_x: usize, screen_y: usize) Pair {
        return .{
            (screen_x - self.pixel_offset_x) / self.scale,
            (screen_y - self.pixel_offset_y) / self.scale,
        };
    }

    pub inline fn getIntScale(self: Self) u32 {
        return std.math.pow(u32, SCALING_BASE, self.scale_factor);
    }
};

fn displayBlock(block: *const Block(u32), params: DisplayParams, screen_x: i32, screen_y: i32) void {
    const scale: i32 = @intCast(params.getIntScale());

    var y: i32 = 0;
    for (block.rows) |row| {
        defer y += 1;
        if (row.isEmpty()) {
            continue;
        }

        const cell_screen_y: i32 = screen_y + y * scale;
        if (!(cell_screen_y + scale >= 0 and cell_screen_y < params.height)) {
            continue;
        }

        var x: i32 = 0;
        var row_iterator = row.iterator();
        while (row_iterator.next()) |cell| : (x += 1) {
            if (cell == 0) {
                continue;
            }

            const cell_screen_x: i32 = screen_x + x * scale;
            if (!(cell_screen_x + scale >= 0 and cell_screen_x < params.width)) {
                continue;
            }

            if (scale <= 1) {
                rl.drawPixel(
                    cell_screen_x,
                    cell_screen_y,
                    DRAW_COLOR,
                );
            } else {
                rl.drawRectangle(
                    cell_screen_x,
                    cell_screen_y,
                    scale,
                    scale,
                    DRAW_COLOR,
                );
            }
        }
    }
}

pub fn displayField(field: Field, params: DisplayParams) void {
    const block_pixel_size: u32 = @as(u32, Field.get_block_size()) * params.getIntScale();

    var block_iterator = field.blocks.iterator();
    while (block_iterator.next()) |entry| {
        const coords = entry.key_ptr;
        const block_x, const block_y = coords.*;
        const block = entry.value_ptr;

        const block_screen_x = (block_x * block_pixel_size) + params.pixel_offset_x;
        if ((block_screen_x + block_pixel_size) < 0 or block_screen_x > params.width) {
            continue;
        }

        const block_screen_y = (block_y * block_pixel_size) + params.pixel_offset_y;
        if ((block_screen_y + block_pixel_size) < 0 or block_screen_y > params.width) {
            continue;
        }

        displayBlock(
            block.*,
            params,
            @intCast(block_screen_x),
            @intCast(block_screen_y),
        );
    }
}
