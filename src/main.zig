const std = @import("std");
const rl = @import("raylib");
const display = @import("display.zig");
const models = @import("models.zig");
const Field = models.Field;
const library = @import("library.zig");
const engine = @import("engine.zig");
const calculate_field_next_state = engine.calculate_field_next_state;

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 600;
    const frame_skip = 10;

    const display_params = display.DisplayParams{
        .width = screenWidth,
        .height = screenHeight,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var field = Field.init(allocator);
    defer field.deinit();

    library.putObject(&field, library.GLIDER, 1, 1);
    library.putObject(&field, library.SPACESHIP, 1, 10);

    rl.initWindow(screenWidth, screenHeight, "Game of Life");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var frame_count: u32 = 0;
    while (!rl.windowShouldClose()) : (frame_count += 1) { // Detect window close button or ESC key
        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        display.displayField(field, display_params);

        // Update
        if (frame_count % frame_skip == 0) {
            const next_state = calculate_field_next_state(field);
            field.deinit();
            field = next_state;
        }
    }
}
