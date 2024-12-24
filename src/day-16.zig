const std = @import("std");

const Position = struct {
    x: usize,
    y: usize,

    pub fn eql(self: @This(), other: @This()) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn dir(self: @This(), other: @This()) Direction {
        if (self.x == other.x) {
            return if (self.y < other.y) .down else .up;
        }

        return if (self.x < other.x) .right else .left;
    }
};

const Direction = enum {
    up,
    left,
    right,
    down,

    pub fn calcTurns(self: @This(), other: @This()) u2 {
        if (self == other)
            return 0;

        if (self.opposite() == other)
            return 2;

        return 1;
    }

    pub fn ccw(self: @This()) @This() {
        return switch (self) {
            .up => .left,
            .left => .down,
            .down => .right,
            .right => .up,
        };
    }

    pub fn cw(self: @This()) @This() {
        return switch (self) {
            .up => .right,
            .right => .down,
            .down => .left,
            .left => .up,
        };
    }

    pub fn opposite(self: @This()) @This() {
        return switch (self) {
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
        };
    }
};

const Map = struct {
    lines: usize,
    columns: usize,
    tiles: std.DynamicBitSet,

    fn keyOf(self: @This(), pos: Position) usize {
        return pos.y * self.columns + pos.x;
    }

    fn posAtOffset(self: @This(), pos: Position, direction: Direction, offset: usize) ?Position {
        return switch (direction) {
            .up => if (offset > pos.y) return null else Position{ .x = pos.x, .y = pos.y - offset },
            .down => if (pos.y + offset >= self.lines) return null else Position{ .x = pos.x, .y = pos.y + offset },
            .left => if (offset > pos.x) return null else Position{ .x = pos.x - offset, .y = pos.y },
            .right => if (offset + pos.x > self.columns) return null else Position{ .x = pos.x + offset, .y = pos.y },
        };
    }

    fn isWall(self: @This(), pos: Position) bool {
        self.assertPosInBounds(pos) catch return false;

        return self.tiles.isSet(pos.y * self.columns + pos.x);
    }

    fn neighbors(self: @This(), buffer: *[4]Position, pos: Position) []Position {
        var len: usize = 0;
        inline for (&[_]Direction{ .up, .right, .down, .left }) |dir| {
            if (self.posAtOffset(pos, dir, 1)) |n_pos| {
                if (!self.isWall(n_pos)) {
                    buffer[len] = n_pos;
                    len += 1;
                }
            }
        }

        return buffer[0..len];
    }

    fn assertPosInBounds(self: @This(), pos: Position) !void {
        if (pos.x >= self.columns or pos.y >= self.lines)
            return error.OutOfBounds;
    }

    fn print(self: @This(), start_pos: ?Position, end_pos: ?Position) void {
        var l: usize = 0;
        while (l < self.lines) : (l += 1) {
            var c: usize = 0;
            while (c < self.columns) : (c += 1) {
                const pos = Position{ .x = c, .y = l };

                if (start_pos) |start| {
                    if (pos.x == start.x and pos.y == start.y) {
                        std.debug.print("S", .{});
                        continue;
                    }
                }

                if (end_pos) |end| {
                    if (pos.x == end.x and pos.y == end.y) {
                        std.debug.print("E", .{});
                        continue;
                    }
                }

                const char: u8 = if (self.isWall(pos)) '#' else '.';
                std.debug.print(
                    "{c}",
                    .{char},
                );
            }

            std.debug.print("\n", .{});
        }
    }
};

const InputData = struct {
    alloc: std.mem.Allocator,
    map: Map,
    start_pos: Position,
    end_pos: Position,
    start_dir: Direction = .right,

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
        const start = try readPosOf(content.items, 'S');
        const end = try readPosOf(content.items, 'E');

        return @This(){
            .alloc = std.heap.page_allocator,
            .map = map,
            .start_pos = start,
            .end_pos = end,
        };
    }

    fn readMap(content: []const u8) !Map {
        const line_len = std.mem.indexOf(u8, content, "\r\n") orelse return error.InvalidMap;
        const lines = @divTrunc(content.len + line_len, line_len + 2);

        var map = try std.DynamicBitSet.initEmpty(
            std.heap.page_allocator,
            line_len * lines,
        );

        var i: usize = 0;
        for (content) |c| {
            switch (c) {
                '\r', '\n' => {},
                '#' => {
                    map.set(i);
                    i += 1;
                },
                else => i += 1,
            }
        }

        return Map{
            .lines = lines,
            .columns = line_len,
            .tiles = map,
        };
    }

    fn readPosOf(content: []const u8, char: u8) !Position {
        const index = std.mem.indexOfScalar(u8, content, char) orelse return error.InvalidMap;
        const line_len = 2 + (std.mem.indexOf(u8, content, "\r\n") orelse return error.InvalidMap);

        return .{ .x = index % line_len, .y = @divTrunc(index, line_len) };
    }

    pub fn deinit(self: *@This()) void {
        self.map.tiles.deinit();
    }
};

const Node = struct {
    pos: Position,
    dir: Direction,
    score: u64,

    pub fn compare(_: void, a: @This(), b: @This()) std.math.Order {
        return std.math.order(a.score, b.score);
    }
};

fn firstHalf(input: *InputData) !void {
    std.debug.print("{d},{d}\n", .{ input.map.columns, input.map.lines });
    input.map.print(input.start_pos, input.end_pos);

    var queue = std.PriorityQueue(Node, void, Node.compare).init(input.alloc, {});
    defer queue.deinit();

    var visited = std.AutoHashMap(usize, Node).init(input.alloc);
    defer visited.deinit();

    try queue.add(.{
        .pos = input.start_pos,
        .dir = input.start_dir,
        .score = 0,
    });

    while (queue.removeOrNull()) |node| {
        if (visited.get(node.pos.y * input.map.columns + node.pos.x)) |_| {
            continue;
        }

        try visited.put(node.pos.y * input.map.columns + node.pos.x, node);

        var neighbors: [4]Position = undefined;
        for (input.map.neighbors(&neighbors, node.pos)) |n_pos| {
            const n_dir = node.pos.dir(n_pos);
            try queue.add(.{
                .pos = n_pos,
                .dir = n_dir,
                .score = node.score + @as(u64, 1000) * node.dir.calcTurns(n_dir) + 1,
            });
        }
    }

    std.debug.print("score: {d}\n", .{
        visited.get(
            input.end_pos.y * input.map.columns + input.end_pos.x,
        ) orelse return error.MissingNode,
    });
}

const BackTrackNode = struct {
    node: Node,
    prev_node: ?Node,
};

fn secondHalf(input: *InputData) !void {
    std.debug.print("{d},{d}\n", .{ input.map.columns, input.map.lines });
    input.map.print(input.start_pos, input.end_pos);

    var queue = std.PriorityQueue(Node, void, Node.compare).init(input.alloc, {});
    defer queue.deinit();

    var visited = std.AutoHashMap(usize, Node).init(input.alloc);
    defer visited.deinit();

    try queue.add(.{
        .pos = input.start_pos,
        .dir = input.start_dir,
        .score = 0,
    });

    while (queue.removeOrNull()) |node| {
        if (visited.get(input.map.keyOf(node.pos))) |_| {
            continue;
        }

        try visited.put(input.map.keyOf(node.pos), node);

        var neighbors: [4]Position = undefined;
        for (input.map.neighbors(&neighbors, node.pos)) |n_pos| {
            const n_dir = node.pos.dir(n_pos);
            try queue.add(.{
                .pos = n_pos,
                .dir = n_dir,
                .score = node.score + @as(u64, 1000) * node.dir.calcTurns(n_dir) + 1,
            });
        }
    }

    var index: usize = 0;
    var back_nodes = std.ArrayList(BackTrackNode).init(input.alloc);
    defer back_nodes.deinit();

    try back_nodes.append(.{
        .node = visited.get(input.map.keyOf(input.end_pos)) orelse return error.MissingNode,
        .prev_node = null,
    });

    while (index < back_nodes.items.len) : (index += 1) {
        const bc_node = back_nodes.items[index];
        var node = bc_node.node;
        var neighbors: [4]Position = undefined;

        if (node.pos.eql(input.start_pos))
            continue;

        if (bc_node.prev_node) |parent| {
            const dir_to_parent = node.pos.dir(parent.pos);
            const turns = node.dir.calcTurns(dir_to_parent);

            node.score += @as(u64, 1000) * turns;
            node.dir = dir_to_parent;
        }

        for (input.map.neighbors(&neighbors, node.pos)) |n_pos| {
            const neighbor = visited.get(input.map.keyOf(n_pos)) orelse return error.MissingNode;

            const turns_to_neighbor = neighbor.pos.dir(node.pos).calcTurns(node.dir);
            const expected_score = std.math.sub(
                u64,
                node.score,
                @as(u64, 1000) * turns_to_neighbor + 1,
            ) catch 0;

            if (neighbor.score > expected_score)
                continue;

            const has_pos = has_pos_lbl: {
                for (back_nodes.items[index..]) |n| {
                    if (n.node.pos.eql(neighbor.pos))
                        break :has_pos_lbl true;
                }
                break :has_pos_lbl false;
            };

            if (!has_pos) {
                try back_nodes.append(.{
                    .node = neighbor,
                    .prev_node = node,
                });
            }
        }
    }

    std.debug.print("visited: {d}\n", .{back_nodes.items.len});
}

pub fn execute() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.print("{s}\n", .{@tagName(gpa.deinit())});

    var input_data = try InputData.parse(gpa.allocator(), "data/day-16.txt");
    defer input_data.deinit();

    try secondHalf(&input_data);
}
