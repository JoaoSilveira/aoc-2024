const std = @import("std");
const lines = 103;
const columns = 101;

const Position = struct {
    x: usize,
    y: usize,

    pub fn move(self: @This(), velocity: Velocity) @This() {
        var out: Position = undefined;

        if (velocity.x < 0) {
            out.x = self.x + (columns - @as(usize, @intCast(@rem(-velocity.x, columns))));
        } else {
            out.x = self.x + @as(usize, @intCast(velocity.x));
        }
        if (velocity.y < 0) {
            out.y = self.y + (lines - @as(usize, @intCast(@rem(-velocity.y, lines))));
        } else {
            out.y = self.y + @as(usize, @intCast(velocity.y));
        }
        out.x %= columns;
        out.y %= lines;

        return out;
    }
};

const Velocity = struct {
    x: i32,
    y: i32,

    pub fn mul(self: @This(), value: i32) @This() {
        return .{
            .x = self.x * value,
            .y = self.y * value,
        };
    }
};

const Robot = struct {
    pos: Position,
    vel: Velocity,
};

const InputData = struct {
    alloc: std.mem.Allocator,
    robots: []Robot,

    pub fn parse(alloc: std.mem.Allocator, path: []const u8) !@This() {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var reader = file.reader();
        var content = std.ArrayList(u8).init(alloc);
        defer content.deinit();

        try reader.readAllArrayList(
            &content,
            std.math.maxInt(usize),
        );

        var robots = std.ArrayList(Robot).init(std.heap.page_allocator);
        defer robots.deinit();

        var iter = std.mem.splitSequence(u8, content.items, "\r\n");
        while (iter.next()) |line| {
            if (line.len < 1)
                continue;
            try robots.append(try parseRobot(line));
        }

        return @This(){
            .alloc = std.heap.page_allocator,
            .robots = try robots.toOwnedSlice(),
        };
    }

    fn parseRobot(line: []const u8) !Robot {
        const first_comma = std.mem.indexOfScalar(u8, line, ',') orelse return error.InvalidLine;
        const last_comma = std.mem.lastIndexOfScalar(u8, line, ',') orelse return error.InvalidLine;
        const space = std.mem.indexOfScalar(u8, line, ' ') orelse return error.InvalidLine;

        return Robot{
            .pos = .{
                .x = try std.fmt.parseInt(usize, line[2..first_comma], 10),
                .y = try std.fmt.parseInt(usize, line[first_comma + 1 .. space], 10),
            },
            .vel = .{
                .x = try std.fmt.parseInt(i32, line[space + 3 .. last_comma], 10),
                .y = try std.fmt.parseInt(i32, line[last_comma + 1 ..], 10),
            },
        };
    }

    pub fn deinit(self: @This()) void {
        self.alloc.free(self.robots);
    }
};

fn firstHalf(input: *InputData) !void {
    const seconds = 100;
    const mx = @divTrunc(columns, 2);
    const my = @divTrunc(lines, 2);

    var q1: u64 = 0;
    var q2: u64 = 0;
    var q3: u64 = 0;
    var q4: u64 = 0;

    for (input.robots) |robot| {
        const end_position = robot.pos.move(robot.vel.mul(seconds));

        if (end_position.x == mx or end_position.y == my)
            continue;

        if (end_position.x < mx) {
            if (end_position.y < my) {
                q1 += 1;
            } else {
                q3 += 1;
            }
        } else {
            if (end_position.y < my) {
                q2 += 1;
            } else {
                q4 += 1;
            }
        }
    }

    std.debug.print("safety: {d}\n", .{q1 * q2 * q3 * q4});
}

fn findRobotInPos(robots: []Robot, pos: Position) bool {
    for (robots) |r| {
        if (r.pos.x == pos.x and r.pos.y == pos.y)
            return true;
    }

    return false;
}

fn secondHalf(input: *InputData) !void {
    var secs: u32 = 0;

    while (true) : (secs += 1) {
        for (0..lines) |line| {
            var line_len: u32 = 0;

            for (0..columns) |column| {
                if (findRobotInPos(input.robots, .{ .x = column, .y = line })) {
                    line_len += 1;

                    if (line_len > 10) {
                        std.debug.print("tree at {d}\n", .{secs});
                        return;
                    }

                    continue;
                }

                line_len = 0;
            }
        }

        for (input.robots) |*r| {
            r.pos = r.pos.move(r.vel);
        }
    }
}

pub fn execute() !void {
    var input_data = try InputData.parse(std.heap.page_allocator, "data/day-14.txt");
    defer input_data.deinit();

    try secondHalf(&input_data);
}
