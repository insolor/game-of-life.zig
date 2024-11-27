const rl = @import("raylib");

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 600;

    rl.initWindow(screenWidth, screenHeight, "Game of Life");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        // TODO

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        rl.drawText(
            "Congrats! You created your first window!",
            190,
            280,
            20,
            rl.Color.light_gray,
        );
    }
}
