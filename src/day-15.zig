const std = @import("std");

const TileType = enum {
    wall,
    box,
    empty,
};

const Position = struct {
    x: usize,
    y: usize,
};

const Map = struct {
    lines: usize,
    columns: usize,
    tiles: []TileType,

    pub fn nextEmptyPos(self: @This(), pos: Position, direction: Movement) ?Position {
        self.assertPosInBounds(pos) catch return null;

        var offset: usize = 1;
        while (true) : (offset += 1) {
            const off_pos = self.posAtOffset(pos, direction, offset) orelse return null;

            switch (self.tileAtPos(off_pos) orelse unreachable) {
                .wall => return null,
                .box => continue,
                .empty => return off_pos,
            }
        }
    }

    pub fn moveToEmpty(self: *@This(), pos: Position, direction: Movement) !void {
        var empty_pos = pos;
        while (true) {
            const box_pos = self.posAtOffset(empty_pos, direction.opposite(), 1) orelse return;

            switch (self.tileAtPos(box_pos) orelse unreachable) {
                .empty => return,
                .box => {
                    self.swapTile(empty_pos, box_pos) catch unreachable;
                    empty_pos = box_pos;
                },
                .wall => return error.InvalidMovement,
            }
        }
    }

    fn posAtOffset(self: @This(), pos: Position, direction: Movement, offset: usize) ?Position {
        return switch (direction) {
            .up => if (offset > pos.y) return null else Position{ .x = pos.x, .y = pos.y - offset },
            .down => if (pos.y + offset >= self.lines) return null else Position{ .x = pos.x, .y = pos.y + offset },
            .left => if (offset > pos.x) return null else Position{ .x = pos.x - offset, .y = pos.y },
            .right => if (offset + pos.x > self.columns) return null else Position{ .x = pos.x + offset, .y = pos.y },
        };
    }

    fn swapTile(self: *@This(), a: Position, b: Position) !void {
        try self.assertPosInBounds(a);
        try self.assertPosInBounds(b);

        std.mem.swap(
            TileType,
            &self.tiles[a.y * self.columns + a.x],
            &self.tiles[b.y * self.columns + b.x],
        );
    }

    fn tileAtPos(self: @This(), pos: Position) ?TileType {
        self.assertPosInBounds(pos) catch return null;

        return self.tiles[pos.y * self.columns + pos.x];
    }

    fn assertPosInBounds(self: @This(), pos: Position) !void {
        if (pos.x >= self.columns or pos.y >= self.lines)
            return error.OutOfBounds;
    }

    fn print(self: @This()) void {
        var l: usize = 0;
        while (l < self.lines) : (l += 1) {
            var c: usize = 0;
            while (c < self.columns) : (c += 1) {
                const pos = Position{ .x = c, .y = l };
                const char: u8 = switch (self.tileAtPos(pos).?) {
                    .wall => '#',
                    .empty => '.',
                    .box => 'O',
                };
                std.debug.print(
                    "{c}",
                    .{char},
                );
            }

            std.debug.print("\n", .{});
        }
    }
};

const Movement = enum {
    up,
    left,
    right,
    down,

    pub fn opposite(self: @This()) @This() {
        return switch (self) {
            .up => .down,
            .left => .right,
            .right => .left,
            .down => .up,
        };
    }
};

const InputData = struct {
    alloc: std.mem.Allocator,
    map: Map,
    moves: []Movement,
    robot_position: Position,

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

        const map = try readMap(content.items);
        const moves = try readMoves(content.items);
        const robot_pos = try readRobotPos(content.items);

        return @This(){
            .alloc = std.heap.page_allocator,
            .map = map,
            .moves = moves,
            .robot_position = robot_pos,
        };
    }

    fn readMap(content: []const u8) !Map {
        var map = std.ArrayList(TileType).init(std.heap.page_allocator);
        defer map.deinit();

        var lines: usize = 0;
        var iter = std.mem.splitSequence(u8, content, "\r\n");
        while (iter.next()) |line| {
            if (line.len == 0) {
                break;
            }

            try parseMapLine(&map, line);
            lines += 1;
        }

        return Map{
            .lines = lines,
            .columns = @divExact(map.items.len, lines),
            .tiles = try map.toOwnedSlice(),
        };
    }

    fn parseMapLine(map: *std.ArrayList(TileType), line: []const u8) !void {
        for (line) |c| {
            try map.append(switch (c) {
                '#' => .wall,
                '.', '@' => .empty,
                'O' => .box,
                else => return error.InvalidMapChar,
            });
        }
    }

    fn readMoves(content: []const u8) ![]Movement {
        var moves = std.ArrayList(Movement).init(std.heap.page_allocator);
        defer moves.deinit();

        var iter = std.mem.splitSequence(u8, content, "\r\n");
        while (iter.next()) |l| {
            if (l.len == 0)
                break;
        }

        while (iter.next()) |line| {
            try moves.ensureUnusedCapacity(line.len);

            for (line) |move| {
                moves.appendAssumeCapacity(switch (move) {
                    '^' => .up,
                    '<' => .left,
                    '>' => .right,
                    'v' => .down,
                    else => return error.InvalidMoveChar,
                });
            }
        }

        return try moves.toOwnedSlice();
    }

    fn readRobotPos(content: []const u8) !Position {
        const index = std.mem.indexOfScalar(u8, content, '@') orelse return error.InvalidMap;
        const line_len = 2 + (std.mem.indexOf(u8, content, "\r\n") orelse return error.InvalidMap);

        return .{ .x = index % line_len, .y = @divTrunc(index, line_len) };
    }

    pub fn deinit(self: @This()) void {
        self.alloc.free(self.map.tiles);
        self.alloc.free(self.moves);
    }
};

fn firstHalf(input: *InputData) !void {
    for (input.moves) |move| {
        const empty_pos = input.map.nextEmptyPos(input.robot_position, move);

        // std.debug.print("robot: {any}\n", .{input.robot_position});
        // std.debug.print("{any} {?any}\n", .{ move, empty_pos });

        if (empty_pos) |pos| {
            try input.map.moveToEmpty(pos, move);
            input.robot_position = input.map.posAtOffset(
                input.robot_position,
                move,
                1,
            ) orelse return error.InvalidRobotMovement;

            // input.map.print();
            // std.debug.print("\n", .{});
        }
    }

    var total_coords: u64 = 0;
    for (input.map.tiles, 0..) |tile, offset| {
        if (tile != .box)
            continue;

        const x = offset % input.map.columns;
        const y = @divTrunc(offset, input.map.columns);

        total_coords += y * 100 + x;
    }

    std.debug.print("coords: {d}\n", .{total_coords});
}

fn secondHalf(input: *InputData) !void {
    _ = input;
}

pub fn execute() !void {
    var input_data = try InputData.parse(std.heap.page_allocator, "data/day-15.txt");
    defer input_data.deinit();

    try firstHalf(&input_data);
}
