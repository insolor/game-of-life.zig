//! Main application class
const std = @import("std");
const rl = @import("raylib");
const display = @import("display.zig");
const models = @import("models.zig");
const Field = models.Field;
const engine = @import("engine.zig");

/// A set of parameters needed to control view panning with the middle mouse button
const PanningParams = struct {
    initial_mouse_x: isize,
    initial_mouse_y: isize,
    initial_offset_x: isize,
    initial_offset_y: isize,

    fn offsetX(self: @This(), mouse_x: isize) isize {
        return self.initial_offset_x + mouse_x - self.initial_mouse_x;
    }

    fn offsetY(self: @This(), mouse_y: isize) isize {
        return self.initial_offset_y + mouse_y - self.initial_mouse_y;
    }
};

allocator: std.mem.Allocator,
field: Field,
display_params: display.DisplayParams,
panning_params: ?PanningParams = null,

frame_skip: usize = 10,
is_running: bool = true,
step: bool = false,

const keyboard_panning_cells_step = 5;

const Self = @This();

pub fn init(allocator: std.mem.Allocator, screen_width: usize, screen_height: usize) Self {
    return .{
        .allocator = allocator,
        .field = Field.init(allocator),
        .display_params = .{
            .width = screen_width,
            .height = screen_height,
        },
    };
}

pub fn deinit(self: *Self) void {
    rl.closeWindow();
    self.field.deinit();
}

fn initDisplay(self: Self) void {
    rl.initWindow(
        @intCast(self.display_params.width),
        @intCast(self.display_params.height),
        "Game of Life",
    );
    rl.setExitKey(.q);
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

fn editField(self: *Self) !void {
    if (self.is_running) {
        return;
    }

    if (rl.isKeyPressed(.f11)) {
        self.field.clear();
        return;
    }

    const mouse = Self.getMousePosition();
    const field_coords = self.display_params.screenToFieldsCoords(
        @intCast(mouse.x),
        @intCast(mouse.y),
    );

    if (rl.isMouseButtonPressed(.left)) {
        try self.field.setOn(field_coords.x, field_coords.y);
    } else if (rl.isMouseButtonPressed(.right)) {
        try self.field.setOff(field_coords.x, field_coords.y);
    }
}

fn scaling(self: *Self) void {
    const mouse_wheel: isize = @intFromFloat(rl.getMouseWheelMove());
    if (mouse_wheel != 0) {
        const mouse = Self.getMousePosition();
        self.display_params.zoomAt(
            mouse.x,
            mouse.y,
            mouse_wheel,
        );
    }
}

fn getMousePosition() struct { x: isize, y: isize } {
    const mouse = rl.getMousePosition();
    return .{
        .x = @intFromFloat(mouse.x),
        .y = @intFromFloat(mouse.y),
    };
}

fn panning(self: *Self) void {
    // Finish view panning on middle mouse button release
    if (rl.isMouseButtonUp(.middle)) {
        self.panning_params = null;
        return;
    }

    const mouse = Self.getMousePosition();
    if (self.panning_params) |panning_params| {
        // Recalculate offset during the panning
        self.display_params.pixel_offset_x = panning_params.offsetX(mouse.x);
        self.display_params.pixel_offset_y = panning_params.offsetY(mouse.y);
    } else if (rl.isMouseButtonDown(.middle)) {
        // Start view panning on middle mouse button press
        self.panning_params = .{
            .initial_mouse_x = mouse.x,
            .initial_mouse_y = mouse.y,
            .initial_offset_x = self.display_params.pixel_offset_x,
            .initial_offset_y = self.display_params.pixel_offset_y,
        };
    }
}

pub fn run(self: *Self) !void {
    self.initDisplay();

    var frame_count: usize = 0;
    while (!rl.windowShouldClose()) : (frame_count += 1) {
        self.keyboardControls();
        self.panning();
        self.scaling();
        try self.editField();
        self.draw();
        if ((self.is_running or self.step) and frame_count % self.frame_skip == 0) {
            try self.nextFieldState();
            self.step = false;
        }
    }
}
