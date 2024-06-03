const std = @import("std");
const rl = @import("raylib");

const screen_width = 800;
const screen_height = 450;

const ball_radius = 10;

const paddle_x = 20;
const paddle_width = 10;
const paddle_height = 100;
const paddle_speed = 8;

const starting_ball_vel_range = rl.Vector2.init(2, 5);
const max_vel = 20.0;

const multiplier = 1.2;

const padding = 20;

const Ball = struct {
    pos: rl.Vector2,
    vel: rl.Vector2,

    fn init(rng: std.Random) @This() {
        var x = randRangeFloat(rng, starting_ball_vel_range.x, starting_ball_vel_range.y);
        if (rng.float(f32) > 0.5) {
            x *= -1;
        }

        var y = randRangeFloat(rng, starting_ball_vel_range.x, starting_ball_vel_range.y);
        if (rng.float(f32) > 0.5) {
            y *= -1;
        }

        return .{
            .pos = rl.Vector2.init(screen_width / 2, screen_height / 2),
            .vel = rl.Vector2.init(x, y),
        };
    }

    fn update(self: *Ball) void {
        self.pos.x += self.vel.x;
        self.pos.y += self.vel.y;

        // clamp the velocity
        if (self.vel.x > max_vel) {
            self.vel.x = max_vel;
        }
        if (self.vel.y > max_vel) {
            self.vel.y = max_vel;
        }
    }

    fn draw(self: Ball) void {
        rl.drawRectangleRoundedLinesEx(rl.Rectangle.init(
            self.pos.x - ball_radius,
            self.pos.y - ball_radius,
            ball_radius * 2,
            ball_radius * 2,
        ), ball_radius, 4, 4, rl.Color.pink);
    }
};

const Paddle = struct {
    pos: rl.Vector2,
    vel: rl.Vector2,

    fn init(x: f32) @This() {
        return .{
            .pos = rl.Vector2.init(x, screen_height / 2 - paddle_height / 2 + padding),
            .vel = rl.Vector2.init(0.0, 0.0),
        };
    }

    fn draw(self: Paddle) void {
        rl.drawRectangleRoundedLinesEx(
            rl.Rectangle.init(self.pos.x, self.pos.y, paddle_width, paddle_height),
            0.01,
            1,
            4,
            rl.Color.gold,
        );
    }
};

const Score = struct {
    player: i32 = 0,
    ai: i32 = 0,

    fn init() @This() {
        return .{};
    }

    fn draw(self: Score) void {
        var buffer: [256]u8 = undefined;
        const score_str = std.fmt.bufPrintZ(&buffer, "{} : {}", .{ self.player, self.ai }) catch unreachable;

        const font_size = 40;
        const text_width = rl.measureText(score_str, font_size);

        rl.drawText(score_str, screen_width / 2 - @divFloor(text_width, 2), padding + 20, font_size, rl.Color.gold);
    }
};

const World = struct {
    width: i32 = screen_width,
    height: i32 = screen_height,
    rng: std.Random,

    ball: Ball,
    player_paddle: Paddle,
    ai_paddle: Paddle,
    score: Score = Score.init(),

    playing_area: rl.Rectangle,

    fn init(rng: std.Random) @This() {
        return .{
            .ball = Ball.init(rng),
            .player_paddle = Paddle.init(paddle_x + padding),
            .ai_paddle = Paddle.init(screen_width - padding - paddle_width - paddle_x),
            .playing_area = rl.Rectangle.init(padding, padding, screen_width - padding * 2, screen_height - padding * 2),
            .rng = rng,
        };
    }

    fn update(self: *World) void {
        self.ball.update();

        if (rl.isKeyDown(rl.KeyboardKey.key_down)) {
            self.player_paddle.pos.y += paddle_speed;
        }
        if (rl.isKeyDown(rl.KeyboardKey.key_up)) {
            self.player_paddle.pos.y -= paddle_speed;
        }

        // bounce the ball of the walls
        if (self.ball.pos.x - ball_radius <= padding or self.ball.pos.x + ball_radius >= screen_width - padding) {
            self.ball.vel.x *= -1 * multiplier;
            self.ball.vel.y *= multiplier;
        }
        if (self.ball.pos.y - ball_radius <= padding or self.ball.pos.y + ball_radius >= screen_height - padding) {
            self.ball.vel.y *= -1 * multiplier;
            self.ball.vel.x *= multiplier;
        }

        const player_lost = rl.checkCollisionCircleRec(self.ball.pos, ball_radius, rl.Rectangle.init(
            0,
            -1000,
            padding,
            screen_height + 1000,
        ));

        const ai_lost = rl.checkCollisionCircleRec(self.ball.pos, ball_radius, rl.Rectangle.init(
            screen_width - padding,
            -1000,
            padding,
            screen_height + 1000,
        ));

        if (player_lost) {
            self.score.ai += 1;
        } else if (ai_lost) {
            self.score.player += 1;
        }

        if (player_lost or ai_lost) {
            self.reset();
        }
    }

    fn reset(self: *World) void {
        self.ball = Ball.init(self.rng);
        self.player_paddle = Paddle.init(paddle_x + padding);
        self.ai_paddle = Paddle.init(screen_width - padding - paddle_width - paddle_x);
    }

    fn draw(self: World) void {
        rl.drawRectangleRoundedLinesEx(self.playing_area, 0.01, 1, 2, rl.Color.white);

        self.ball.draw();
        self.player_paddle.draw();
        self.ai_paddle.draw();

        self.score.draw();
    }
};

const frame_rate = 60.0;
const tick_rate = 30.0; // 30 ticks per second

pub fn main() !void {
    var rng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));

    rl.initWindow(screen_width, screen_height, "Hello Raylib");
    defer rl.closeWindow();

    var world = World.init(rng.random());

    const target_tick_rate = 1.0 / tick_rate;
    var accumulated_time: f32 = 0.0;

    rl.setTargetFPS(frame_rate);

    while (!rl.windowShouldClose()) {
        const deltaTime = rl.getFrameTime();
        accumulated_time += deltaTime;

        while (accumulated_time >= target_tick_rate) {
            world.update();
            accumulated_time -= target_tick_rate;
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
