const std = @import("std");
const rl = @import("raylib");
const display = @import("display.zig");
const models = @import("models.zig");
const Field = models.Field;
const library = @import("library.zig");

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 600;

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

    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        // TODO

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        display.displayField(field, display_params);
    }
}
