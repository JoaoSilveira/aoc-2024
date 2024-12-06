const std = @import("std");

pub fn execute() !void {
    var file = try std.fs.cwd().openFile("data/day-02.txt", .{});
    defer file.close();

    var reader = file.reader();
    var line = std.ArrayList(u8).init(std.heap.page_allocator);
    defer line.deinit();

    var report = std.ArrayList(u32).init(std.heap.page_allocator);
    defer report.deinit();

    var safe_reports: u32 = 0;
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

        var iter = std.mem.splitScalar(u8, line.items, ' ');
        while (iter.next()) |number| {
            try report.append(try std.fmt.parseInt(u32, number, 10));
        }

        safe_reports += @intFromBool(isReportSafeDamp(report.items));
        report.clearRetainingCapacity();
    }

    std.debug.print("safe reports: {d}\n", .{safe_reports});
}

fn isReportSafe(report: []u32) bool {
    std.debug.assert(report.len > 1);

    const expected_order = std.math.order(report[0], report[1]);
    for (report[0 .. report.len - 1], report[1..]) |left, right| {
        if (left == right)
            return false;

        const current_order = std.math.order(left, right);
        if (expected_order != current_order)
            return false;

        switch (current_order) {
            .lt => if (right - left > 3) return false,
            .gt => if (left - right > 3) return false,
            else => @panic("should never happen"),
        }
    }

    return true;
}

fn isReportSafeDamp(report: []u32) bool {
    if (isReportSafe(report))
        return true;

    for (1..report.len) |i| {
        if (isReportSafe(report[1..]))
            return true;

        const aux = report[0];
        report[0] = report[i];
        report[i] = aux;
    }

    return isReportSafe(report[1..]);
}
