const std = @import("std");
const rl = @import("raylib");

const screenWidth = 800;
const screenHeight = 450;

const playerX = 20;
const aiX = screenWidth - 20;

const startingVelRange = rl.Vector2.init(5, 5);

const Ball = struct {
    pos: rl.Vector2,
    vel: rl.Vector2,

    fn init(vel: rl.Vector2) @This() {
        std.debug.print("ball init: {}\n", .{vel});

        return .{
            .pos = rl.Vector2.init(screenWidth / 2, screenHeight / 2),
            .vel = vel,
        };
    }

    fn update(self: *Ball) void {
        self.pos.x += self.vel.x;
        self.pos.y += self.vel.y;
    }

    fn draw(self: Ball) void {
        const radius = 16;
        rl.drawRectangleRoundedLinesEx(rl.Rectangle.init(self.pos.x, self.pos.y, radius, radius), radius, 4, 4, rl.Color.pink);
    }
};

const Paddle = struct {
    pos: rl.Vector2,
    vel: rl.Vector2,

    fn init(x: f32) @This() {
        return .{
            .pos = rl.Vector2.init(x, screenHeight / 2),
            .vel = rl.Vector2.init(0.0, 0.0),
        };
    }

    fn draw(self: Paddle) void {
        const height = 100;
        const width = 10;
        rl.drawRectangleRoundedLinesEx(rl.Rectangle.init(self.pos.x, self.pos.y, width, height), 0, 1, 4, rl.Color.gold);
    }
};

const World = struct {
    width: i32 = screenWidth,
    height: i32 = screenHeight,
    rng: std.Random,

    ball: Ball,
    player_paddle: Paddle,
    ai_paddle: Paddle,

    fn init(rng: std.Random) @This() {
        const ball_starting_vel = randomVector2(
            rng,
            startingVelRange.x * -1,
            startingVelRange.x,
            startingVelRange.y * -1,
            startingVelRange.y,
        );

        return .{
            .ball = Ball.init(ball_starting_vel),
            .player_paddle = Paddle.init(playerX),
            .ai_paddle = Paddle.init(aiX),
            .rng = rng,
        };
    }

    fn update(self: *World) void {
        self.ball.update();

        // bounce the ball of the walls
        const height: f32 = @floatFromInt(self.height);
        if (self.ball.pos.y <= 0 or self.ball.pos.y >= height) {
            self.ball.vel.y *= -1.2;
            self.ball.vel.x *= 1.2;
        }
        const width: f32 = @floatFromInt(self.width);
        if (self.ball.pos.x <= 0 or self.ball.pos.x >= width) {
            self.ball.vel.x *= -1.2;
            self.ball.vel.y *= 1.2;
        }
    }

    fn draw(self: World) void {
        self.ball.draw();
        self.player_paddle.draw();
        self.ai_paddle.draw();
    }
};

const frameRate = 60.0;
const tickRate = 30.0; // 30 ticks per second

pub fn main() !void {
    var rng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));

    rl.initWindow(screenWidth, screenHeight, "Hello Raylib");
    defer rl.closeWindow();

    var world = World.init(rng.random());

    const targetTickRate = 1.0 / tickRate;
    var accumulatedTime: f32 = 0.0;

    rl.setTargetFPS(frameRate);

    while (!rl.windowShouldClose()) {
        const deltaTime = rl.getFrameTime();
        accumulatedTime += deltaTime;

        while (accumulatedTime >= targetTickRate) {
            world.update();
            accumulatedTime -= targetTickRate;
        }

        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);
        // rl.drawText("Hello, world!", 10, 10, 20, rl.Color.pink);

        world.draw();

        rl.endDrawing();
    }
}

// Function to generate a random float between min and max
fn randRangeFloat(rng: std.Random, min: f32, max: f32) f32 {
    return min + (max - min) * rng.float(f32);
}

// Function to generate a random Vector2
fn randomVector2(rnd: std.Random, minX: f32, maxX: f32, minY: f32, maxY: f32) rl.Vector2 {
    return rl.Vector2{
        .x = randRangeFloat(rnd, minX, maxX),
        .y = randRangeFloat(rnd, minY, maxY),
    };
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
