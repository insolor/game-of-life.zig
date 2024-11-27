const rl = @import("raylib");

const models = @import("models.zig");
const Pair = models.Pair;
const Block = models.Block;
const Field = models.Field;

const DRAW_COLOR = rl.Color.white;

pub const DisplayParams = struct {
    width: usize,
    height: usize,
    scale: usize,
    pixel_offset_x: isize = 0,
    pixel_offset_y: isize = 0,

    const Self = @This();

    fn scaleAt(self: Self, mouse_x: usize, mouse_y: usize, new_scale: usize) void {
        const old_scale = self.scale;
        self.pixel_offset_x = (self.pixel_offset_x - mouse_x) * new_scale / old_scale + mouse_x;
        self.pixel_offset_y = (self.pixel_offset_y - mouse_y) * new_scale / old_scale + mouse_y;
        self.scale = new_scale;
    }

    fn screenToFieldsCoords(self: Self, screen_x: usize, screen_y: usize) Pair {
        return .{
            (screen_x - self.pixel_offset_x) / self.scale,
            (screen_y - self.pixel_offset_y) / self.scale,
        };
    }
};

fn displayBlock(block: Block(Field.get_block_size()), params: DisplayParams, screen_x: usize, screen_y: usize) void {
    for (0..block.get_block_size(), block.rows) |y, row| {
        if (row.isEmpty()) {
            continue;
        }

        const cell_screen_y = screen_y + y * params.scale;
        if (!(cell_screen_y + params.scale >= 0 or cell_screen_y < params.height)) {
            continue;
        }

        var x: usize = 0;
        while (row.iterator()) |cell| : (x += 1) {
            if (cell == 0) {
                continue;
            }

            const cell_screen_x = screen_x + x * params.scale;
            if (!(cell_screen_x + params.scale >= 0 or cell_screen_x < params.width)) {
                continue;
            }

            if (params.scale <= 1) {
                rl.drawPixel(
                    cell_screen_x,
                    cell_screen_y,
                    DRAW_COLOR,
                );
            } else {
                rl.drawRectangle(
                    cell_screen_x,
                    cell_screen_y,
                    params.scale,
                    params.scale,
                    DRAW_COLOR,
                );
            }
        }
    }
}

pub fn displayField(field: Field, params: DisplayParams) void {
    const block_pixel_size = field.get_block_size() * params.scale;

    while (field.blocks.iterator()) |entry| {
        const coords, const block = entry.*;

        const block_screen_x = (coords.block_x * block_pixel_size) + params.pixel_offset_x;
        if (!(block_screen_x + block_pixel_size >= 0 or block_screen_x < params.width)) {
            continue;
        }

        const block_screen_y = (coords.block_y * block_pixel_size) + params.pixel_offset_y;
        if (!(block_screen_x + block_pixel_size >= 0 or block_screen_x < params.width)) {
            continue;
        }

        displayBlock(block, params, block_screen_x, block_screen_y);
    }
}
