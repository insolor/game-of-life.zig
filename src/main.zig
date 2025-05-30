const std = @import("std");
const rl = @import("raylib");
const display = @import("display.zig");
const models = @import("models.zig");
const Field = models.Field;
const object_library = @import("object_library.zig");
const engine = @import("engine.zig");
const pow = std.math.pow;

const PanningParams = struct {
    initial_mouse_x: isize,
    initial_mouse_y: isize,
    initial_offset_x: isize,
    initial_offset_y: isize,

    const Self = @This();
    fn offsetX(self: Self, mouse_x: isize) isize {
        return self.initial_offset_x + mouse_x - self.initial_mouse_x;
    }

    fn offsetY(self: Self, mouse_y: isize) isize {
        return self.initial_offset_y + mouse_y - self.initial_mouse_y;
    }
};

const App = struct {
    allocator: std.mem.Allocator,
    field: Field,
    display_params: display.DisplayParams,
    panning_params: ?PanningParams = null,

    frame_skip: usize = 10,
    is_running: bool = true,
    step: bool = false,

    const keyboard_panning_cells_step = 5;

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
        rl.setExitKey(rl.KeyboardKey.q);
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

    fn keyboardControls(self: *Self) void {
        switch (rl.getKeyPressed()) {
            .space => {
                // start/stop
                self.is_running = !self.is_running;
            },
            .enter => {
                // run step by step
                self.is_running = false;
                self.step = true;
            },
            .kp_add => {
                // numpad plus - run faster
                if (!self.is_running) {
                    self.is_running = true;
                } else {
                    self.frame_skip = @max(1, self.frame_skip - 1);
                }
            },
            .kp_subtract => {
                // numpad minus - run slower
                if (!self.is_running) {
                    self.is_running = true;
                } else {
                    self.frame_skip = self.frame_skip + 1;
                }
            },
            .w, .up => {
                // pan up
                self.display_params.pixel_offset_y += keyboard_panning_cells_step * self.display_params.getIntScale();
            },
            .s, .down => {
                // pan down
                self.display_params.pixel_offset_y -= keyboard_panning_cells_step * self.display_params.getIntScale();
            },
            .a, .left => {
                // pan left
                self.display_params.pixel_offset_x += keyboard_panning_cells_step * self.display_params.getIntScale();
            },
            .d, .right => {
                // pan right
                self.display_params.pixel_offset_x -= keyboard_panning_cells_step * self.display_params.getIntScale();
            },
            else => {},
        }
    }

    fn scaling(self: *Self) void {
        const mouse_wheel: isize = @intFromFloat(rl.getMouseWheelMove());
        if (mouse_wheel != 0) {
            const old_scale_factor = self.display_params.scale_factor;
            const new_scale_factor = @min(255, @max(0, old_scale_factor + mouse_wheel));
            const mouse_position = Self.getMousePosition();
            self.display_params.scaleAt(
                mouse_position.x,
                mouse_position.y,
                new_scale_factor,
            );
        }
    }

    fn getMousePosition() struct { x: isize, y: isize } {
        const mouse_position = rl.getMousePosition();
        return .{
            .x = @intFromFloat(mouse_position.x),
            .y = @intFromFloat(mouse_position.y),
        };
    }

    fn panning(self: *Self) void {
        // Finish view panning on middle mouse button release
        if (rl.isMouseButtonUp(rl.MouseButton.middle)) {
            self.panning_params = null;
            return;
        }

        const mouse_position = Self.getMousePosition();
        if (self.panning_params) |panning_params| {
            // Recalculate offset during the panning
            self.display_params.pixel_offset_x = panning_params.offsetX(mouse_position.x);
            self.display_params.pixel_offset_y = panning_params.offsetY(mouse_position.y);
        } else if (rl.isMouseButtonDown(rl.MouseButton.middle)) {
            // Start view panning on middle mouse button press
            self.panning_params = .{
                .initial_mouse_x = mouse_position.x,
                .initial_mouse_y = mouse_position.y,
                .initial_offset_x = self.display_params.pixel_offset_x,
                .initial_offset_y = self.display_params.pixel_offset_y,
            };
        }
    }

    fn run(self: *Self) !void {
        self.initDisplay();

        var frame_count: usize = 0;
        while (!rl.windowShouldClose()) : (frame_count += 1) {
            self.keyboardControls();
            self.panning();
            self.scaling();
            self.draw();
            if ((self.is_running or self.step) and frame_count % self.frame_skip == 0) {
                try self.nextFieldState();
                self.step = false;
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
