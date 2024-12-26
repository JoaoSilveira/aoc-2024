const std = @import("std");

const InputData = struct {
    alloc: std.mem.Allocator,
    content: []u8,
    towels: [][]const u8,
    arrangements: [][]const u8,

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

        const content_slice = try content.toOwnedSlice();
        errdefer alloc.free(content_slice);

        var iter = std.mem.splitSequence(u8, content_slice, "\r\n");
        const towels = try parseTowels(alloc, iter.next() orelse return error.InvalidInput);
        _ = iter.next();

        var arrangements = std.ArrayListUnmanaged([]const u8).empty;
        while (iter.next()) |arrangement| {
            if (arrangement.len == 0)
                continue;

            try arrangements.append(alloc, arrangement);
        }

        return @This(){
            .alloc = alloc,
            .content = content_slice,
            .towels = towels,
            .arrangements = try arrangements.toOwnedSlice(alloc),
        };
    }

    pub fn parseTowels(alloc: std.mem.Allocator, line: []const u8) ![][]const u8 {
        var towels = std.ArrayListUnmanaged([]const u8).empty;

        var iter = std.mem.splitSequence(u8, line, ", ");
        while (iter.next()) |towel| {
            if (towel.len == 0)
                continue;

            try towels.append(alloc, towel);
        }

        return try towels.toOwnedSlice(alloc);
    }

    pub fn deinit(self: *@This()) void {
        self.alloc.free(self.arrangements);
        self.alloc.free(self.towels);
        self.alloc.free(self.content);
    }
};

fn firstHalf(input: *InputData) !void {
    var possible: u64 = 0;

    arr_loop: for (input.arrangements) |arr| {
        var solutions = std.ArrayListUnmanaged([]const u8).empty;
        defer solutions.deinit(input.alloc);

        try solutions.append(input.alloc, arr);

        while (solutions.items.len > 0) {
            const sol = solutions.swapRemove(0);

            for (input.towels) |towel| {
                if (std.mem.startsWith(u8, sol, towel)) {
                    if (sol.len == towel.len) {
                        possible += 1;
                        continue :arr_loop;
                    }

                    try solutions.append(input.alloc, sol[towel.len..]);
                }
            }
        }
    }

    std.debug.print("possible: {d}\n", .{possible});
}

fn findSolutions(seen: *std.StringHashMap(u64), towels: [][]const u8, arr: []const u8) !u64 {
    if (arr.len == 0)
        return 1;

    if (seen.get(arr)) |count| {
        return count;
    }

    var count: u64 = 0;
    for (towels) |towel| {
        if (std.mem.startsWith(u8, arr, towel)) {
            count += try findSolutions(seen, towels, arr[towel.len..]);
        }
    }

    try seen.put(arr, count);

    return count;
}

fn secondHalf(input: *InputData) !void {
    var seen_map = std.StringHashMap(u64).init(input.alloc);
    defer seen_map.deinit();

    var total: u64 = 0;
    for (input.arrangements) |arr| {
        defer seen_map.clearRetainingCapacity();

        const sols = try findSolutions(&seen_map, input.towels, arr);
        total += sols;
        std.debug.print("{s}: {d}\n", .{ arr, sols });
    }

    std.debug.print("total: {d}\n", .{total});
}

pub fn execute() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.print("{s}\n", .{@tagName(gpa.deinit())});

    var input_data = try InputData.parse(gpa.allocator(), "data/day-19.txt");
    defer input_data.deinit();

    try secondHalf(&input_data);
}
