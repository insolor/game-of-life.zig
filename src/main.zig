const std = @import("std");
const rl = @import("raylib");
const display = @import("display.zig");
const models = @import("models.zig");
const Field = models.Field;
const object_library = @import("object_library.zig");
const engine = @import("engine.zig");

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

    field.putObject(object_library.GLIDER, 1, 1);
    field.putObject(object_library.SPACESHIP, 1, 10);

    rl.initWindow(screenWidth, screenHeight, "Game of Life");
    defer rl.closeWindow();

    rl.setExitKey(rl.KeyboardKey.null); // Don't exit on Esc key press

    rl.setTargetFPS(60);

    var frame_count: u32 = 0;
    while (!rl.windowShouldClose()) : (frame_count += 1) {
        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        display.displayField(field, display_params);

        // Update
        if (frame_count % frame_skip == 0) {
            const next_state = engine.calculateFieldNextState(field);
            field.deinit();
            field = next_state;
        }
    }
}
