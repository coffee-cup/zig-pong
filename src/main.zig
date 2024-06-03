const std = @import("std");
const rl = @import("raylib");

const screenWidth = 800;
const screenHeight = 450;

const Ball = struct {
    pos: rl.Vector2,
    vel: rl.Vector2,

    fn init() Ball {
        return .{
            .pos = rl.Vector2.init(screenWidth / 2, screenHeight / 2),
            .vel = rl.Vector2.init(0.0, 0.0),
        };
    }

    fn draw(self: Ball) void {
        const radius = 16;
        rl.drawRectangleRoundedLinesEx(rl.Rectangle.init(self.pos.x, self.pos.y, radius, radius), radius, 4, 4, rl.Color.pink);
    }
};

pub fn main() !void {
    rl.initWindow(screenWidth, screenHeight, "Hello Raylib");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    const ball = Ball.init();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);
        rl.drawText("Hello, world!", 10, 10, 20, rl.Color.pink);

        ball.draw();

        rl.endDrawing();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
