const std = @import("std");

pub fn execute() !void {
    var file = try std.fs.cwd().openFile("data/day-01.txt", .{});
    defer file.close();

    var reader = file.reader();
    var line = std.ArrayList(u8).init(std.heap.page_allocator);
    defer line.deinit();

    var left = std.ArrayList(u32).init(std.heap.page_allocator);
    defer left.deinit();
    var right = std.ArrayList(u32).init(std.heap.page_allocator);
    defer right.deinit();

    while (true) {
        reader.readUntilDelimiterArrayList(
            &line,
            '\n',
            std.math.maxInt(usize),
        ) catch |err| {
            switch (err) {
                error.EndOfStream => if (line.items.len <= 0) break,
                else => return err,
            }
        };

        if (line.items.len > 0 and line.items[line.items.len - 1] == '\r') {
            line.items.len -= 1;
        }

        const maybe_idx = std.mem.indexOf(u8, line.items, "   ");
        if (maybe_idx) |idx| {
            try left.append(try std.fmt.parseInt(u32, line.items[0..idx], 10));
            try right.append(try std.fmt.parseInt(u32, line.items[idx + 3 ..], 10));
        } else {
            return error.InvalidLine;
        }
    }

    std.mem.sort(u32, left.items, {}, std.sort.asc(u32));
    std.mem.sort(u32, right.items, {}, std.sort.asc(u32));

    std.debug.print("similarity: {d}", .{similarityScore(left.items, right.items)});
}

fn distanceOf(left: []const u32, right: []const u32) u64 {
    var distance: u64 = 0;
    for (left.items, right.items) |l, r| {
        distance += @abs(l - r);
    }

    return distance;
}

fn dumbSimilarityScore(left: []const u32, right: []const u32) u64 {
    var score: u64 = 0;
    for (left) |l| {
        var count: u64 = 0;
        for (right) |r| {
            count += @intFromBool(l == r);
        }
        score += l * count;
    }

    return score;
}

fn similarityScore(left: []const u32, right: []const u32) u64 {
    var totalScore: u64 = 0;

    var count: u64 = 0;
    var right_index: usize = 0;
    for (left, 0..) |l, i| {
        if (right_index >= right.len)
            break;

        if (i > 0 and left[i - 1] == l) {
            totalScore += l * count;
            continue;
        }

        count = 0;
        while (right_index < right.len and l > right[right_index])
            right_index += 1;

        while (right_index < right.len and l == right[right_index]) {
            right_index += 1;
            count += 1;
        }

        totalScore += l * count;
    }

    return totalScore;
}
