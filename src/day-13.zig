const std = @import("std");

const LinearSystem = struct {
    x1: u64,
    x2: u64,
    y1: u64,
    y2: u64,
    rx: u64,
    ry: u64,

    pub fn gaussianElimination(self: @This()) !struct { u64, u64 } {
        var sys = self;

        if (self.x1 == 0) {
            if (self.y1 == 0)
                return error.Unsolvable;

            std.mem.swap(u64, &sys.x1, &sys.x2);
            std.mem.swap(u64, &sys.y1, &sys.y2);
            std.mem.swap(u64, &sys.rx, &sys.ry);
        }

        if (std.math.sub(u64, sys.y2 * sys.x1, sys.x2 * sys.y1)) |val| {
            sys.y2 = val;
            sys.ry = std.math.sub(u64, sys.ry * sys.x1, sys.rx * sys.y1) catch return error.Unsolvable;
        } else |_| {
            sys.y2 = std.math.sub(u64, sys.x2 * sys.y1, sys.y2 * sys.x1) catch return error.Unsolvable;
            sys.ry = std.math.sub(u64, sys.rx * sys.y1, sys.ry * sys.x1) catch return error.Unsolvable;
        }

        if (sys.y2 == 0) {
            return error.Unsolvable;
        }

        sys.ry = std.math.divExact(u64, sys.ry, sys.y2) catch return error.Unsolvable;
        sys.rx = std.math.sub(u64, sys.rx, sys.x2 * sys.ry) catch return error.Unsolvable;
        sys.rx = std.math.divExact(u64, sys.rx, sys.x1) catch return error.Unsolvable;

        return .{ sys.rx, sys.ry };
    }
};

const InputData = struct {
    alloc: std.mem.Allocator,
    equations: []LinearSystem,

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

        var equations = std.ArrayList(LinearSystem).init(alloc);
        defer equations.deinit();

        var iter = std.mem.splitSequence(u8, content.items, "\r\n");
        while (parseSystem(&iter)) |system| {
            try equations.append(system);
            _ = iter.next(); // skip empty line
        } else |err| {
            if (err != error.IteratorEnded)
                return err;
        }

        return @This(){
            .alloc = alloc,
            .equations = try equations.toOwnedSlice(),
        };
    }

    fn parseSystem(iter: *std.mem.SplitIterator(u8, .sequence)) !LinearSystem {
        const button_a = try parseButton(iter.next() orelse return error.IteratorEnded);
        const button_b = try parseButton(iter.next() orelse return error.InvalidLine);
        const target = try parseTarget(iter.next() orelse return error.InvalidLine);

        return LinearSystem{
            .x1 = button_a[0],
            .x2 = button_b[0],
            .rx = target[0],
            .y1 = button_a[1],
            .y2 = button_b[1],
            .ry = target[1],
        };
    }

    fn parseButton(line: []const u8) !struct { u64, u64 } {
        const prefix_len = "Button A: X+".len;

        const comma_index = std.mem.indexOfScalar(u8, line, ',');
        const last_plus = std.mem.lastIndexOfScalar(u8, line, '+');

        if (comma_index == null or last_plus == null)
            return error.InvalidButtonLine;

        return .{
            try std.fmt.parseInt(u64, line[prefix_len..comma_index.?], 10),
            try std.fmt.parseInt(u64, line[last_plus.? + 1 ..], 10),
        };
    }

    fn parseTarget(line: []const u8) !struct { u64, u64 } {
        const prefix_len = "Prize: X=".len;

        const comma_index = std.mem.indexOfScalar(u8, line, ',');
        const last_plus = std.mem.lastIndexOfScalar(u8, line, '=');

        if (comma_index == null or last_plus == null)
            return error.InvalidButtonLine;

        return .{
            try std.fmt.parseInt(u64, line[prefix_len..comma_index.?], 10),
            try std.fmt.parseInt(u64, line[last_plus.? + 1 ..], 10),
        };
    }

    pub fn deinit(self: @This()) void {
        self.alloc.free(self.equations);
    }
};

fn firstHalf(input: *InputData) !void {
    var tokens: u64 = 0;
    for (input.equations) |sys| {
        const sol = sys.gaussianElimination() catch |e| {
            if (e != error.Unsolvable) return e;

            continue;
        };

        tokens += sol[0] * 3 + sol[1];
    }

    std.debug.print("tokens: {d}\n", .{tokens});
}

fn secondHalf(input: *InputData) !void {
    const offset = 10000000000000;

    var tokens: u64 = 0;
    for (input.equations) |*sys| {
        sys.rx += offset;
        sys.ry += offset;

        const sol = sys.gaussianElimination() catch |e| {
            if (e != error.Unsolvable) return e;

            continue;
        };

        tokens += sol[0] * 3 + sol[1];
    }

    std.debug.print("tokens: {d}\n", .{tokens});
}

pub fn execute() !void {
    var input_data = try InputData.parse(std.heap.page_allocator, "data/day-13.txt");
    defer input_data.deinit();

    try secondHalf(&input_data);
}
