const std = @import("std");

const Distance = struct {
    x: i32,
    y: i32,
};

fn addI32(a: usize, b: i32) !usize {
    if (b < 0)
        return std.math.sub(usize, a, @as(usize, @intCast(-b)));

    return std.math.add(usize, a, @as(usize, @intCast(b)));
}

fn subI32(a: usize, b: i32) !usize {
    if (b < 0)
        return std.math.add(usize, a, @as(usize, @intCast(-b)));

    return std.math.sub(usize, a, @as(usize, @intCast(b)));
}

const Antenna = struct {
    code: u8,
    line: usize,
    column: usize,

    pub fn distance(self: @This(), other: @This()) Distance {
        return .{
            .x = @as(i32, @intCast(other.column)) - @as(i32, @intCast(self.column)),
            .y = @as(i32, @intCast(other.line)) - @as(i32, @intCast(self.line)),
        };
    }

    pub fn add(self: @This(), dist: Distance) !@This() {
        return .{
            .code = self.code,
            .line = try addI32(self.line, dist.y),
            .column = try addI32(self.column, dist.x),
        };
    }

    pub fn sub(self: @This(), dist: Distance) !@This() {
        return .{
            .code = self.code,
            .line = try subI32(self.line, dist.y),
            .column = try subI32(self.column, dist.x),
        };
    }
};

const InputData = struct {
    alloc: std.mem.Allocator,
    antennae: []Antenna,
    lines: usize,
    columns: usize,

    pub fn deinit(self: @This()) void {
        self.alloc.free(self.antennae);
    }
};

fn parseInput() !InputData {
    var file = try std.fs.cwd().openFile("data/day-08.txt", .{});
    defer file.close();

    var reader = file.reader();
    var content = std.ArrayList(u8).init(std.heap.page_allocator);
    defer content.deinit();

    try reader.readAllArrayList(
        &content,
        std.math.maxInt(usize),
    );

    var antennae = std.ArrayList(Antenna).init(std.heap.page_allocator);
    defer antennae.deinit();
    const line_len = 1 + (std.mem.indexOfScalar(u8, content.items, '\n') orelse return error.MissingNewLine);

    for (content.items, 0..) |code, i| {
        switch (code) {
            'a'...'z', 'A'...'Z', '0'...'9' => {
                try antennae.append(.{
                    .code = code,
                    .line = @divTrunc(i, line_len),
                    .column = i % line_len,
                });
            },
            else => {},
        }
    }

    return InputData{
        .alloc = std.heap.page_allocator,
        .antennae = try antennae.toOwnedSlice(),
        .lines = @divTrunc(content.items.len + line_len - 1, line_len),
        .columns = line_len - 1 - @intFromBool(content.items[line_len - 2] == '\r'),
    };
}

fn firstHalf(input: InputData) !void {
    var antinodes = try std.bit_set.DynamicBitSet.initEmpty(
        input.alloc,
        input.lines * input.columns,
    );
    defer antinodes.deinit();

    var count: usize = 0;
    for (input.antennae[0 .. input.antennae.len - 1], 1..) |antenna, i| {
        for (input.antennae[i..]) |other| {
            if (other.code != antenna.code)
                continue;

            const delta = antenna.distance(other);

            if (antenna.sub(delta)) |anti| {
                if (anti.line < input.lines and anti.column < input.columns) {
                    count += @intFromBool(!antinodes.isSet(anti.line * input.columns + anti.column));
                    antinodes.set(anti.line * input.columns + anti.column);
                }
            } else |_| {}

            if (other.add(delta)) |anti| {
                if (anti.line < input.lines and anti.column < input.columns) {
                    count += @intFromBool(!antinodes.isSet(anti.line * input.columns + anti.column));
                    antinodes.set(anti.line * input.columns + anti.column);
                }
            } else |_| {}
        }
    }

    std.debug.print("antinodes: {d}\n", .{count});
}

fn secondHalf(input: InputData) !void {
    var antinodes = try std.bit_set.DynamicBitSet.initEmpty(
        input.alloc,
        input.lines * input.columns,
    );
    defer antinodes.deinit();

    var count: usize = 0;
    for (input.antennae[0 .. input.antennae.len - 1], 1..) |antenna, i| {
        for (input.antennae[i..]) |other| {
            if (other.code != antenna.code)
                continue;

            count += @intFromBool(!antinodes.isSet(antenna.line * input.columns + antenna.column));
            count += @intFromBool(!antinodes.isSet(other.line * input.columns + other.column));

            antinodes.set(antenna.line * input.columns + antenna.column);
            antinodes.set(other.line * input.columns + other.column);
            const delta = antenna.distance(other);

            var aux = antenna;
            while (aux.sub(delta)) |anti| {
                aux = anti;
                if (anti.line >= input.lines or anti.column >= input.columns)
                    break;

                count += @intFromBool(!antinodes.isSet(anti.line * input.columns + anti.column));
                antinodes.set(anti.line * input.columns + anti.column);
            } else |_| {}

            aux = other;
            while (aux.add(delta)) |anti| {
                aux = anti;
                if (anti.line >= input.lines or anti.column >= input.columns)
                    break;

                count += @intFromBool(!antinodes.isSet(anti.line * input.columns + anti.column));
                antinodes.set(anti.line * input.columns + anti.column);
            } else |_| {}
        }
    }

    std.debug.print("antinodes: {d}\n", .{count});
}

pub fn execute() !void {
    const input = try parseInput();
    defer input.deinit();

    try secondHalf(input);
}
