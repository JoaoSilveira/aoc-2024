const std = @import("std");

const map_dim = 71;
const bytes_taken = 1024;

const Position = struct {
    x: usize,
    y: usize,

    pub fn toOffset(self: @This()) usize {
        return self.y * map_dim + self.x;
    }

    pub fn atOffset(self: @This(), dir: Direction, offset: usize) ?@This() {
        return switch (dir) {
            .up => if (offset > self.y) return null else Position{ .x = self.x, .y = self.y - offset },
            .down => if (self.y + offset >= map_dim) return null else Position{ .x = self.x, .y = self.y + offset },
            .left => if (offset > self.x) return null else Position{ .x = self.x - offset, .y = self.y },
            .right => if (self.x + offset >= map_dim) return null else Position{ .x = self.x + offset, .y = self.y },
        };
    }
};

const Direction = enum {
    up,
    right,
    down,
    left,
};

const Map = struct {
    tiles: std.DynamicBitSet,

    fn neighbors(self: @This(), buffer: *[4]Position, pos: Position) []Position {
        var index: usize = 0;

        inline for ([_]Direction{ .up, .right, .down, .left }) |dir| {
            if (pos.atOffset(dir, 1)) |neighbor| {
                if (!self.tiles.isSet(neighbor.toOffset())) {
                    buffer[index] = neighbor;
                    index += 1;
                }
            }
        }

        return buffer[0..index];
    }

    fn print(self: @This()) void {
        var buff: [map_dim]u8 = undefined;

        var row: usize = 0;

        while (row < map_dim) : (row += 1) {
            var col: usize = 0;
            while (col < map_dim) : (col += 1) {
                const pos = Position{ .x = col, .y = row };
                buff[col] = if (self.tiles.isSet(pos.toOffset())) '#' else '.';
            }

            std.debug.print("{s}\n", .{buff[0..]});
        }
    }
};

const InputData = struct {
    alloc: std.mem.Allocator,
    positions: []Position,
    map: Map,

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

        var map = try std.DynamicBitSet.initEmpty(alloc, map_dim * map_dim);
        errdefer map.deinit();

        var positions = std.ArrayList(Position).init(alloc);
        defer positions.deinit();

        var iter = std.mem.splitSequence(u8, content.items, "\r\n");
        while (iter.next()) |line| {
            const pos = try parsePos(line);

            try positions.append(pos);
        }

        return @This(){
            .alloc = alloc,
            .positions = try positions.toOwnedSlice(),
            .map = .{ .tiles = map },
        };
    }

    fn parsePos(line: []const u8) !Position {
        const comma_index = std.mem.indexOfScalar(u8, line, ',') orelse return error.InvalidPosition;

        return .{
            .x = try std.fmt.parseInt(usize, line[0..comma_index], 10),
            .y = try std.fmt.parseInt(usize, line[comma_index + 1 ..], 10),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.map.tiles.deinit();
        self.alloc.free(self.positions);
    }
};

const Node = struct {
    pos: Position,
    score: u64,
    parent: ?*Node,

    pub fn compare(_: void, a: *const @This(), b: *const @This()) std.math.Order {
        return std.math.order(a.score, b.score);
    }
};

fn createNode(alloc: std.mem.Allocator, node: Node) !*Node {
    const new_node = try alloc.create(Node);

    new_node.* = node;

    return new_node;
}

fn dijkstra(
    alloc: std.mem.Allocator,
    map: Map,
    visited: *std.AutoHashMap(usize, *Node),
) !void {
    var unvisited = std.PriorityQueue(*Node, void, Node.compare).init(alloc, {});
    defer unvisited.deinit();

    try unvisited.add(try createNode(alloc, .{
        .pos = .{ .x = 0, .y = 0 },
        .score = 0,
        .parent = null,
    }));

    while (unvisited.removeOrNull()) |node| {
        if (visited.get(node.pos.toOffset())) |_| {
            alloc.destroy(node);
            continue;
        }

        try visited.put(node.pos.toOffset(), node);

        var buffer: [4]Position = undefined;
        for (map.neighbors(&buffer, node.pos)) |neighbor| {
            try unvisited.add(try createNode(alloc, .{
                .pos = neighbor,
                .score = node.score + 1,
                .parent = node,
            }));
        }
    }
}

fn firstHalf(input: *InputData) !void {
    for (input.positions[0..bytes_taken]) |p| {
        input.map.tiles.set(p.toOffset());
    }

    input.map.print();
    std.debug.print("\n", .{});

    var visited = std.AutoHashMap(usize, *Node).init(input.alloc);
    defer {
        var iter = visited.valueIterator();
        while (iter.next()) |v| {
            input.alloc.destroy(v.*);
        }
        visited.deinit();
    }

    try dijkstra(input.alloc, input.map, &visited);

    const end_pos = Position{ .x = map_dim - 1, .y = map_dim - 1 };
    const end_node = visited.get(end_pos.toOffset()) orelse return error.NoRouteFound;

    std.debug.print("score: {d}\n", .{end_node.score});
}

fn secondHalf(input: *InputData) !void {
    const end_pos = Position{ .x = map_dim - 1, .y = map_dim - 1 };
    for (input.positions) |pos| {
        input.map.tiles.set(pos.toOffset());

        var visited = std.AutoHashMap(usize, *Node).init(input.alloc);
        defer {
            var iter = visited.valueIterator();
            while (iter.next()) |v| {
                input.alloc.destroy(v.*);
            }
            visited.deinit();
        }

        try dijkstra(input.alloc, input.map, &visited);

        if (visited.get(end_pos.toOffset())) |_| {} else {
            std.debug.print("Pos: {d},{d}\n", .{ pos.x, pos.y });
            break;
        }
    }
}

pub fn execute() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.print("{s}\n", .{@tagName(gpa.deinit())});

    var input_data = try InputData.parse(gpa.allocator(), "data/day-18.txt");
    defer input_data.deinit();

    try secondHalf(&input_data);
}
