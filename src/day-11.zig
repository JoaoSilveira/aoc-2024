const std = @import("std");

const InputData = struct {
    alloc: std.mem.Allocator,
    input: []u8,

    pub fn deinit(self: @This()) void {
        self.alloc.free(self.input);
    }
};

var cache = std.AutoArrayHashMap(u64, u64).init(std.heap.page_allocator);

fn parseInput() !InputData {
    var file = try std.fs.cwd().openFile("data/day-11.txt", .{});
    defer file.close();

    var reader = file.reader();
    var content = std.ArrayList(u8).init(std.heap.page_allocator);
    defer content.deinit();

    try reader.readAllArrayList(
        &content,
        std.math.maxInt(usize),
    );

    content.items.len = std.mem.trimRight(
        u8,
        content.items,
        "\r\n",
    ).len;

    return InputData{
        .alloc = std.heap.page_allocator,
        .input = try content.toOwnedSlice(),
    };
}

fn countDigits(number: u64) u8 {
    var digits: u8 = 1;
    var value: u64 = 10;

    while (value <= number) {
        digits += 1;
        value *= 10;
    }

    return digits;
}

fn countStones(number: u64, depth: u8) !u64 {
    // std.debug.print("n: {d} | {d}\n", .{ number, depth });
    if (depth == 75)
        return 1;

    const key = number * 100 + depth;
    if (cache.get(key)) |stones| {
        return stones;
    }

    if (number == 0) {
        const stones = try countStones(1, depth + 1);
        try cache.put(key, stones);
        return stones;
    }

    const digits = countDigits(number);
    if (digits % 2 == 0) {
        const power = std.math.pow(u64, 10, @divTrunc(digits, 2));
        const stones = try countStones(@divTrunc(number, power), depth + 1) +
            try countStones(number % power, depth + 1);
        try cache.put(key, stones);
        return stones;
    } else {
        const stones = try countStones(number * 2024, depth + 1);
        try cache.put(key, stones);
        return stones;
    }
}

fn firstHalf(input: *InputData) !void {
    var total_stones: u64 = 0;
    var iter = std.mem.splitScalar(u8, input.input, ' ');

    while (iter.next()) |digits| {
        const number = try std.fmt.parseInt(u64, digits, 10);
        total_stones += try countStones(number, 0);
    }

    std.debug.print("stones: {d}\n", .{total_stones});
}

fn secondHalf(input: *InputData) !void {
    _ = input;
}

pub fn execute() !void {
    var input = try parseInput();
    defer input.deinit();
    defer cache.deinit();

    try firstHalf(&input);
}
