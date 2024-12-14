const std = @import("std");

const Position = struct {
    x: usize,
    y: usize,
};

pub const Matrix = struct {
    line_length: usize,
    chars_in_line: usize,
    content: []u8,

    pub fn lines(self: @This()) usize {
        return @divTrunc(self.content.len + self.line_length - 1, self.line_length);
    }

    pub fn columns(self: @This()) usize {
        return self.chars_in_line;
    }

    pub fn charAt(self: @This(), pos: Position) ?u8 {
        self.checkInsideBounds(pos) catch return null;

        return self.content[self.posOffset(pos).?];
    }

    pub fn posOffset(self: @This(), pos: Position) ?usize {
        self.checkInsideBounds(pos) catch return null;

        return pos.y * self.line_length + pos.x;
    }

    pub fn offsetToPos(self: @This(), offset: usize) ?Position {
        if (offset >= self.content.len) return null;

        const pos = Position{
            .y = @divTrunc(offset, self.line_length),
            .x = offset % self.line_length,
        };

        return if (self.checkInsideBounds(pos)) pos else |_| null;
    }

    fn checkInsideBounds(self: @This(), pos: Position) !void {
        if (pos.y >= self.lines() or pos.x >= self.columns())
            return error.OutOfBounds;
    }
};

const InputData = struct {
    alloc: std.mem.Allocator,
    map: Matrix,

    pub fn deinit(self: @This()) void {
        self.alloc.free(self.map.content);
    }
};

fn parseInput() !InputData {
    var file = try std.fs.cwd().openFile("data/day-10.txt", .{});
    defer file.close();

    var reader = file.reader();
    var content = std.ArrayList(u8).init(std.heap.page_allocator);
    defer content.deinit();

    try reader.readAllArrayList(
        &content,
        std.math.maxInt(usize),
    );

    const mat = Matrix{
        .line_length = 1 + (std.mem.indexOfScalar(u8, content.items, '\n') orelse return error.InvalidInput),
        .chars_in_line = std.mem.indexOfAny(u8, content.items, "\r\n") orelse return error.InvalidInput,
        .content = try content.toOwnedSlice(),
    };

    return InputData{
        .alloc = std.heap.page_allocator,
        .map = mat,
    };
}

fn calculateHeadScore(alloc: std.mem.Allocator, map: Matrix, trail_head: Position) !u64 {
    var stack = std.ArrayList(Position).init(alloc);
    defer stack.deinit();
    var hits = std.ArrayList(Position).init(alloc);
    defer hits.deinit();

    try stack.append(trail_head);

    var score: u64 = 0;
    while (stack.items.len > 0) {
        const pos = stack.pop();

        // std.debug.print("at {d},{d} - {?c} || ", .{
        //     pos.x,
        //     pos.y,
        //     map.charAt(pos),
        // });

        if (map.charAt(pos) == '9') {
            for (hits.items) |i| {
                if (pos.x == i.x and pos.y == i.y)
                    break;
            } else {
                score += 1;
                try hits.append(pos);
            }
            // std.debug.print("ended\n", .{});
            continue;
        }

        const next_height = map.charAt(pos).? + 1;
        if (pos.x > 0 and map.charAt(.{ .x = pos.x - 1, .y = pos.y }) == next_height) {
            // std.debug.print("L", .{});
            try stack.append(.{ .x = pos.x - 1, .y = pos.y });
        }
        if (pos.y > 0 and map.charAt(.{ .x = pos.x, .y = pos.y - 1 }) == next_height) {
            // std.debug.print("T", .{});
            try stack.append(.{ .x = pos.x, .y = pos.y - 1 });
        }
        if (pos.x < map.columns() and map.charAt(.{ .x = pos.x + 1, .y = pos.y }) == next_height) {
            // std.debug.print("R", .{});
            try stack.append(.{ .x = pos.x + 1, .y = pos.y });
        }
        if (pos.y < map.lines() and map.charAt(.{ .x = pos.x, .y = pos.y + 1 }) == next_height) {
            // std.debug.print("B", .{});
            try stack.append(.{ .x = pos.x, .y = pos.y + 1 });
        }
        // std.debug.print("\n", .{});
    }

    return score;
}

fn calculateHeadRating(alloc: std.mem.Allocator, map: Matrix, trail_head: Position) !u64 {
    var stack = std.ArrayList(Position).init(alloc);
    defer stack.deinit();

    try stack.append(trail_head);

    var score: u64 = 0;
    while (stack.items.len > 0) {
        const pos = stack.pop();

        // std.debug.print("at {d},{d} - {?c} || ", .{
        //     pos.x,
        //     pos.y,
        //     map.charAt(pos),
        // });

        if (map.charAt(pos) == '9') {
            score += 1;
            // std.debug.print("ended\n", .{});
            continue;
        }

        const next_height = map.charAt(pos).? + 1;
        if (pos.x > 0 and map.charAt(.{ .x = pos.x - 1, .y = pos.y }) == next_height) {
            // std.debug.print("L", .{});
            try stack.append(.{ .x = pos.x - 1, .y = pos.y });
        }
        if (pos.y > 0 and map.charAt(.{ .x = pos.x, .y = pos.y - 1 }) == next_height) {
            // std.debug.print("T", .{});
            try stack.append(.{ .x = pos.x, .y = pos.y - 1 });
        }
        if (pos.x < map.columns() and map.charAt(.{ .x = pos.x + 1, .y = pos.y }) == next_height) {
            // std.debug.print("R", .{});
            try stack.append(.{ .x = pos.x + 1, .y = pos.y });
        }
        if (pos.y < map.lines() and map.charAt(.{ .x = pos.x, .y = pos.y + 1 }) == next_height) {
            // std.debug.print("B", .{});
            try stack.append(.{ .x = pos.x, .y = pos.y + 1 });
        }
        // std.debug.print("\n", .{});
    }

    return score;
}

fn firstHalf(input: *InputData) !void {
    var total_score: u64 = 0;

    for (0..input.map.lines()) |line| {
        for (0..input.map.columns()) |column| {
            if (input.map.charAt(.{ .x = column, .y = line }) != '0')
                continue;

            // std.debug.print("Head at {d},{d}\n", .{ column, line });
            total_score += try calculateHeadScore(
                input.alloc,
                input.map,
                .{ .y = line, .x = column },
            );

            // std.debug.print("\n\n", .{});
        }
    }

    std.debug.print("score: {d}\n", .{total_score});
}

fn secondHalf(input: *InputData) !void {
    var total_score: u64 = 0;

    for (0..input.map.lines()) |line| {
        for (0..input.map.columns()) |column| {
            if (input.map.charAt(.{ .x = column, .y = line }) != '0')
                continue;

            // std.debug.print("Head at {d},{d}\n", .{ column, line });
            total_score += try calculateHeadRating(
                input.alloc,
                input.map,
                .{ .y = line, .x = column },
            );

            // std.debug.print("\n\n", .{});
        }
    }

    std.debug.print("score: {d}\n", .{total_score});
}

pub fn execute() !void {
    var input = try parseInput();
    defer input.deinit();

    try secondHalf(&input);
}
