const std = @import("std");
const Pair = struct { u32, u32 };

fn printArray(arr: []const u32) void {
    for (arr) |a| {
        std.debug.print("{d},", .{a});
    }
    std.debug.print("\n", .{});
}

fn pairLessThan(_: void, a: Pair, b: Pair) bool {
    return a[0] < b[0];
}

fn rulesForPage(page: u32, pairs: []const Pair) []const Pair {
    var start_index: ?usize = null;
    for (pairs, 0..) |p, i| {
        if (p[0] != page) {
            if (start_index) |si| {
                return pairs[si..i];
            }

            continue;
        }

        if (start_index) |_| {} else {
            start_index = i;
        }
    }

    return if (start_index) |si| pairs[si..] else &[_]Pair{};
}

fn isUpdateValid(update: []const u32, pairs: []const Pair) bool {
    for (update[1..], 1..) |page, i| {
        const rules = rulesForPage(page, pairs);

        for (update[0..i]) |prev_page| {
            for (rules) |rule| {
                if (rule[1] == prev_page)
                    return false;
            }
        }
    }

    return true;
}

fn orderUpdate(update: []u32, pairs: []const Pair) void {
    for (update[1..], 1..) |page, page_index| {
        const page_rules = rulesForPage(page, pairs);

        prev_loop: for (0..page_index) |prev_index| {
            for (page_rules) |rule| {
                if (rule[1] == update[prev_index]) {
                    std.mem.copyBackwards(
                        u32,
                        update[prev_index + 1 .. page_index + 1],
                        update[prev_index..page_index],
                    );
                    update[prev_index] = page;
                    break :prev_loop;
                }
            }
        }
    }
}

pub fn execute() !void {
    var file = try std.fs.cwd().openFile("data/day-05.txt", .{});
    defer file.close();

    var reader = file.reader();
    var content = std.ArrayList(u8).init(std.heap.page_allocator);
    defer content.deinit();

    try reader.readAllArrayList(
        &content,
        std.math.maxInt(usize),
    );

    var pairs = std.ArrayList(Pair).init(std.heap.page_allocator);
    defer pairs.deinit();

    // parse order rules
    var iter = std.mem.splitSequence(u8, content.items, "\r\n");
    while (iter.next()) |line| {
        if (line.len == 0) break;

        const comma_index = std.mem.indexOfScalar(u8, line, '|') orelse return error.InvalidInput;
        try pairs.append(.{
            try std.fmt.parseInt(u32, line[0..comma_index], 10),
            try std.fmt.parseInt(u32, line[comma_index + 1 ..], 10),
        });
    }

    std.mem.sort(Pair, pairs.items, {}, pairLessThan);

    var update_line = std.ArrayList(u32).init(std.heap.page_allocator);
    defer update_line.deinit();

    // parse update lines
    var sum: u32 = 0;
    while (iter.next()) |line| {
        defer update_line.clearRetainingCapacity();

        var digit_iter = std.mem.splitScalar(u8, line, ',');
        while (digit_iter.next()) |digit| {
            try update_line.append(try std.fmt.parseInt(u32, digit, 10));
        }

        if (!isUpdateValid(update_line.items, pairs.items)) {
            orderUpdate(update_line.items, pairs.items);
            sum += update_line.items[@divTrunc(update_line.items.len, 2)];
        }
    }

    std.debug.print("total: {d}\n", .{sum});
}
