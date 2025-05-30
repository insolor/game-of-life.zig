const std = @import("std");
const rl = @import("raylib");
const display = @import("display.zig");
const models = @import("models.zig");
const Field = models.Field;
const object_library = @import("object_library.zig");
const engine = @import("engine.zig");

const App = struct {
    allocator: std.mem.Allocator,
    field: Field,
    display_params: display.DisplayParams,
    frame_skip: usize = 10,

    const Self = @This();
    fn init(allocator: std.mem.Allocator, screen_width: usize, screen_height: usize) Self {
        return .{
            .allocator = allocator,
            .field = Field.init(allocator),
            .display_params = .{
                .width = screen_width,
                .height = screen_height,
            },
        };
    }

    fn deinit(self: *Self) void {
        rl.closeWindow();
        self.field.deinit();
    }

    fn initDisplay(self: Self) void {
        rl.initWindow(
            @intCast(self.display_params.width),
            @intCast(self.display_params.height),
            "Game of Life",
        );
        rl.setExitKey(rl.KeyboardKey.null); // Don't exit on Esc key press
        rl.setTargetFPS(60);
    }

    fn draw(self: Self) void {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        display.displayField(self.field, self.display_params);
    }

    fn nextFieldState(self: *Self) !void {
        const next_state = try engine.calculateFieldNextState(self.field);
        self.field.deinit();
        self.field = next_state;
    }

    fn run(self: *Self) !void {
        self.initDisplay();

        var frame_count: usize = 0;
        while (!rl.windowShouldClose()) : (frame_count += 1) {
            self.draw();
            if (frame_count % self.frame_skip == 0) {
                try self.nextFieldState();
            }
        }
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var app = App.init(allocator, 800, 600);
    defer app.deinit();

    try app.field.putObject(object_library.GLIDER, 1, 1);
    try app.field.putObject(object_library.SPACESHIP, 1, 10);

    try app.run();
}
