const std = @import("std");
const rl = @import("raylib");

const screen_width = 800;
const screen_height = 450;

const ball_radius = 10;

const paddle_x = 20;
const paddle_width = 10;
const paddle_height = 100;

const player_speed = 12;
const ai_speed = 8;

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

        // Bounce the ball of the walls
        const width: f32 = @floatFromInt(rl.getScreenWidth());
        const height: f32 = @floatFromInt(rl.getScreenHeight());
        if (self.pos.x - ball_radius <= padding or self.pos.x + ball_radius >= width - padding) {
            self.vel.x *= -1 * multiplier;
            self.vel.y *= multiplier;
        }
        if (self.pos.y - ball_radius <= padding or self.pos.y + ball_radius >= height - padding) {
            self.vel.y *= -1 * multiplier;
            self.vel.x *= multiplier;
        }
    }

    fn handle_paddle_collision(self: *Ball, paddle: Paddle) void {
        const paddle_center_y = paddle.pos.y + paddle_height / 2;
        const paddle_relative_intersect_y = (paddle_center_y - self.pos.y) / (paddle_height / 2);
        const max_angle = 35.0;
        const bounce_angle = paddle_relative_intersect_y * max_angle;

        const ball_speed = vectorLength(self.vel);

        // Update the ball's velocity based on the bounce angle
        self.vel.x = ball_speed * std.math.cos(std.math.rad_per_deg * bounce_angle) * if (self.vel.x > 0) @as(f32, -1) else 1;
        self.vel.y = ball_speed * -std.math.sin(std.math.rad_per_deg * bounce_angle);

        // Increase the speed slightly on each hit
        const speed_increase = 1.05;
        self.vel.x += speed_increase;
        self.vel.y += speed_increase;

        // Spin
        self.vel.y += paddle.vel.y * 0.5;

        // Make sure that the ball doesn't get stuck in the paddle
        if (self.vel.x > 0) {
            self.pos.x = paddle.pos.x + paddle_width + ball_radius;
        } else {
            self.pos.x = paddle.pos.x - ball_radius;
        }
    }

    fn draw(self: Ball) void {
        rl.drawCircle(@intFromFloat(self.pos.x), @intFromFloat((self.pos.y)), ball_radius, rl.Color.pink);
        // rl.drawRectangleRoundedLinesEx(rl.Rectangle.init(
        //     self.pos.x - ball_radius,
        //     self.pos.y - ball_radius,
        //     ball_radius * 2,
        //     ball_radius * 2,
        // ), ball_radius * 2, 100, 4, rl.Color.pink);
    }
};

const Paddle = struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    is_ai: bool = true,

    fn init(x: f32, is_ai: bool) @This() {
        return .{
            .pos = rl.Vector2.init(x, screen_height / 2 - paddle_height / 2 + padding),
            .vel = rl.Vector2.init(0.0, 0.0),
            .is_ai = is_ai,
        };
    }

    fn update(self: *Paddle, ball: Ball) void {
        if (self.is_ai) {
            self.move_to_ball(ball);
        } else {
            if (rl.isKeyDown(rl.KeyboardKey.key_down) or rl.isKeyDown(rl.KeyboardKey.key_s)) {
                self.pos.y += player_speed;
            }
            if (rl.isKeyDown(rl.KeyboardKey.key_up) or rl.isKeyDown(rl.KeyboardKey.key_w)) {
                self.pos.y -= player_speed;
            }
        }

        self.pos.y += self.vel.y;

        if (self.pos.y < padding) {
            self.pos.y = padding;
        } else if (self.pos.y + paddle_height > screen_height - padding) {
            self.pos.y = screen_height - padding - paddle_height;
        }
    }

    fn move_to_ball(self: *Paddle, ball: Ball) void {
        const mid_y = self.pos.y + paddle_height / 2;
        const target_y = ball.pos.y + ball_radius;
        const difference = target_y - mid_y;

        const smoothing = 0.1;
        self.vel.y = std.math.clamp(difference * smoothing * ai_speed, -ai_speed, ai_speed);
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

const LastScore = enum { Player, Ai };

const World = struct {
    width: i32 = screen_width,
    height: i32 = screen_height,
    rng: std.Random,

    ball: Ball,
    left_paddle: Paddle,
    right_paddle: Paddle,
    score: Score = Score.init(),

    playing_area: rl.Rectangle,

    last_scored: ?LastScore = null,
    flast_timer: f32 = 0.0,

    fn init(rng: std.Random) @This() {
        return .{
            .ball = Ball.init(rng),
            .left_paddle = Paddle.init(paddle_x + padding, false),
            .right_paddle = Paddle.init(screen_width - padding - paddle_width - paddle_x, true),
            .playing_area = rl.Rectangle.init(padding, padding, screen_width - padding * 2, screen_height - padding * 2),
            .rng = rng,
        };
    }

    fn update(self: *World) void {
        if (rl.isKeyPressed(rl.KeyboardKey.key_r)) {
            self.score.player = 0;
            self.score.ai = 0;
            self.reset();
        }

        self.ball.update();

        self.left_paddle.update(self.ball);
        self.right_paddle.update(self.ball);

        self.flast_timer -= 1.0;

        // Check if the ball hits the paddles
        const player_hit = rl.checkCollisionCircleRec(self.ball.pos, ball_radius, rl.Rectangle.init(
            self.left_paddle.pos.x,
            self.left_paddle.pos.y,
            paddle_width,
            paddle_height,
        ));

        if (player_hit) {
            self.ball.handle_paddle_collision(self.left_paddle);
        }

        const ai_hit = rl.checkCollisionCircleRec(self.ball.pos, ball_radius, rl.Rectangle.init(
            self.right_paddle.pos.x,
            self.right_paddle.pos.y,
            paddle_width,
            paddle_height,
        ));

        if (ai_hit) {
            self.ball.handle_paddle_collision(self.right_paddle);
        }

        // Check if the ball hits the walls behind the paddles
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

        // Update scores and reset game if a player lost
        if (player_lost) {
            self.score.ai += 1;
            self.last_scored = .Ai;
        } else if (ai_lost) {
            self.score.player += 1;
            self.last_scored = .Player;
        }

        if (player_lost or ai_lost) {
            self.flast_timer = 30 * 0.5;
            self.reset();
        }
    }

    fn reset(self: *World) void {
        self.ball = Ball.init(self.rng);
        self.left_paddle = Paddle.init(paddle_x + padding, false);
        self.right_paddle = Paddle.init(screen_width - padding - paddle_width - paddle_x, true);
    }

    fn draw(self: World) void {
        var border_color = rl.Color.ray_white;
        if (self.flast_timer > 0) {
            border_color = if (self.last_scored == .Player) rl.Color.green else rl.Color.red;
        }

        rl.drawRectangleRoundedLinesEx(self.playing_area, 0.01, 1, 2, border_color);

        self.ball.draw();
        self.left_paddle.draw();
        self.right_paddle.draw();

        self.score.draw();
    }
};

const frame_rate = 60.0;
const tick_rate = 30.0; // 30 ticks per second

pub fn main() !void {
    var rng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));

    rl.initWindow(screen_width, screen_height, "pong");
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

fn vectorLength(v: rl.Vector2) f32 {
    return std.math.sqrt(v.x * v.x + v.y * v.y);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
