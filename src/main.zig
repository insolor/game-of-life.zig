const std = @import("std");
const App = @import("App.zig");
const object_library = @import("object_library.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var app = App.init(allocator, 800, 600);
    defer app.deinit();

    try app.engine.field.putObject(object_library.GLIDER, 1, 1);
    try app.engine.field.putObject(object_library.SPACESHIP, 1, 10);

    try app.run();
}
