const std = @import("std");

pub const Matrix = struct {
    line_length: usize,
    chars_in_line: usize,
    content: []u8,

    pub fn init(slice: []u8) !@This() {
        const new_line_idx = std.mem.indexOfScalar(u8, slice, '\n') orelse return error.MissingNewLine;

        return .{
            .chars_in_line = new_line_idx - @intFromBool(slice[new_line_idx - 1] == '\r'),
            .line_length = new_line_idx + 1,
            .content = slice,
        };
    }

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

    pub fn setCharAt(self: *@This(), char: u8, pos: Position) void {
        self.checkInsideBounds(pos) catch return;

        self.content[self.posOffset(pos).?] = char;
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

    pub fn print(self: @This()) void {
        for (0..self.lines()) |line| {
            const offset = line * self.line_length;
            const slice = self.content[offset .. offset + self.chars_in_line];

            std.debug.print("{s}\n", .{slice});
        }
    }
};

const Direction = enum {
    north,
    south,
    east,
    west,

    pub fn rotateRight(self: @This()) @This() {
        return switch (self) {
            .north => .east,
            .east => .south,
            .south => .west,
            .west => .north,
        };
    }
};

const Position = struct {
    x: usize,
    y: usize,

    pub fn moveTo(self: @This(), dir: Direction) ?@This() {
        var x = self.x;
        var y = self.y;

        switch (dir) {
            .north => y = std.math.sub(usize, y, 1) catch return null,
            .south => y = std.math.add(usize, y, 1) catch return null,
            .east => x = std.math.add(usize, x, 1) catch return null,
            .west => x = std.math.sub(usize, x, 1) catch return null,
        }

        return Position{
            .x = x,
            .y = y,
        };
    }
};

const SimmulationResult = enum {
    moves_outside,
    loops,
};

fn simmulateGuard(matrix: Matrix, init_pos: Position, init_dir: Direction) !SimmulationResult {
    var hit_obstacles = std.ArrayList(struct { Position, Direction }).init(std.heap.page_allocator);
    defer hit_obstacles.deinit();

    var pos = init_pos;
    var dir = init_dir;

    while (true) {
        const next_pos = pos.moveTo(dir);

        if (next_pos == null or matrix.charAt(next_pos.?) == null) {
            return .moves_outside;
        }

        // obstacle or wall
        if (next_pos == null or (matrix.charAt(next_pos.?) orelse '#') == '#') {
            const hit = .{ pos, dir };

            for (hit_obstacles.items) |obstacle| {
                if (std.mem.eql(u8, std.mem.asBytes(&hit), std.mem.asBytes(&obstacle))) {
                    return .loops;
                }
            }

            try hit_obstacles.append(hit);
            dir = dir.rotateRight();

            continue;
        }

        if (next_pos) |next| {
            pos = next;
        } else {
            @panic("should never happen because of the previous if");
        }
    }
}

pub fn execute() !void {
    var file = try std.fs.cwd().openFile("data/day-06.txt", .{});
    defer file.close();

    var reader = file.reader();
    var content = std.ArrayList(u8).init(std.heap.page_allocator);
    defer content.deinit();

    try reader.readAllArrayList(
        &content,
        std.math.maxInt(usize),
    );

    var matrix = try Matrix.init(content.items);
    const direction = Direction.north;
    const pos = matrix.offsetToPos(std.mem.indexOfScalar(u8, content.items, '^') orelse return error.MissingGuard) orelse return error.InvalidStartPosition;

    var total: usize = 0;

    for (0..matrix.lines()) |line| {
        for (0..matrix.columns()) |column| {
            const obstacle_pos = Position{ .x = column, .y = line };

            if (matrix.charAt(obstacle_pos) == '#')
                continue;

            matrix.setCharAt('#', obstacle_pos);
            defer matrix.setCharAt('.', obstacle_pos);

            switch (try simmulateGuard(matrix, pos, direction)) {
                .loops => total += 1,
                .moves_outside => {},
            }
        }
    }

    std.debug.print("total: {d}\n", .{total});
}
