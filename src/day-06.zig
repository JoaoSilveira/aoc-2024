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

const LoopDetector = struct {
    last_four_pos: [4]Position,
    length: usize, // how many positions are there

    pub fn init() @This() {
        return @This(){
            .last_four_pos = std.mem.zeroes([4]Position),
            .length = 0,
        };
    }

    pub fn appendPos(self: *@This(), pos: Position) ?Position {
        if (self.length < 4) {
            self.last_four_pos[self.length] = pos;
            self.length += 1;
            return null;
        }
        defer {
            std.mem.copyForwards(
                Position,
                self.last_four_pos[0..3],
                self.last_four_pos[1..4],
            );
            self.last_four_pos[3] = pos;
        }

        const p1 = self.last_four_pos[0];
        const p2 = self.last_four_pos[1];
        const p4 = self.last_four_pos[3];
        const p5 = pos;

        const has_loop = linesIntersect(p1, p2, p4, p5);

        std.debug.print("<path d=\"M{d} {d}L{d} {d}M{d} {d}L{d} {d}\" stroke-width=\".1\" stroke=\"black\"/><!--{any}-->\n", .{
            p1.x,     p1.y,
            p2.x,     p2.y,
            p4.x,     p4.y,
            p5.x,     p5.y,
            has_loop,
        });
        if (!has_loop) return null;

        if (p1.x == p2.x) {
            return Position{
                .x = p1.x,
                .y = p5.y,
            };
        }

        return Position{
            .x = p5.x,
            .y = p1.y,
        };
    }

    fn linesIntersect(p1: Position, p2: Position, p4: Position, p5: Position) bool {
        if (p1.x > p2.x)
            return linesIntersect(p2, p1, p4, p5);

        if (p4.x > p5.x)
            return linesIntersect(p1, p2, p5, p4);

        if (p1.y > p2.y)
            return linesIntersect(p2, p1, p4, p5);

        if (p4.y > p5.y)
            return linesIntersect(p1, p2, p5, p4);

        return (p1.x <= p4.x and p2.x >= p4.x and p4.y <= p1.y and p5.y >= p1.y) or
            (p4.x <= p1.x and p5.x >= p1.x and p1.y <= p4.y and p2.y >= p4.y);
    }
};

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

    // var hit_obstacles = std.ArrayList(struct { Position, Direction }).init(std.heap.page_allocator);
    // defer hit_obstacles.deinit();

    var matrix = try Matrix.init(content.items);
    var direction = Direction.north;
    var loop = LoopDetector.init();
    var pos = matrix.offsetToPos(std.mem.indexOfScalar(u8, content.items, '^') orelse return error.MissingGuard) orelse return error.InvalidStartPosition;

    _ = loop.appendPos(pos);
    var total: usize = 0;
    // walk_loop:
    while (true) {
        const next_pos = pos.moveTo(direction);

        if (next_pos == null or matrix.charAt(next_pos.?) == null) {
            total += @intFromBool(loop.appendPos(pos) != null);
            break;
        }

        // obstacle or wall
        if (next_pos == null or (matrix.charAt(next_pos.?) orelse '#') == '#') {
            total += @intFromBool(loop.appendPos(pos) != null);

            // const hit = .{ pos, direction };

            // for (hit_obstacles.items) |obstacle| {
            //     if (std.mem.eql(u8, std.mem.asBytes(&hit), std.mem.asBytes(&obstacle))) {
            //         break :walk_loop;
            //     }
            // }

            // try hit_obstacles.append(hit);
            direction = direction.rotateRight();

            continue;
        }

        if (next_pos) |next| {
            // matrix.setCharAt('^', next);

            pos = next;
        } else {
            @panic("should never happen because of the previous if");
        }
    }

    std.debug.print("total: {d}\n", .{total});
}
