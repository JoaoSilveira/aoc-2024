const std = @import("std");

fn parseOperand(slice: []const u8, operand: *u32) !usize {
    var index: usize = 0;
    while (index < 3 and index < slice.len and std.ascii.isDigit(slice[index]))
        index += 1;

    operand.* = try std.fmt.parseInt(u32, slice[0..index], 10);
    return index;
}

fn canDoOp(content: []const u8) bool {
    const do_index = std.mem.lastIndexOf(u8, content, "do()");
    const dont_index = std.mem.lastIndexOf(u8, content, "don't()");

    std.debug.print("d {any} - n {any}", .{ do_index, dont_index });
    if (dont_index) |dont_pos| {
        return if (do_index) |do_pos| do_pos > dont_pos else false;
    }

    return true;
}

pub fn execute() !void {
    var file = try std.fs.cwd().openFile("data/day-03.txt", .{});
    defer file.close();

    var reader = file.reader();
    var content = std.ArrayList(u8).init(std.heap.page_allocator);
    defer content.deinit();

    try reader.readAllArrayList(
        &content,
        std.math.maxInt(usize),
    );

    var total: u32 = 0;
    var iter = std.mem.tokenizeSequence(u8, content.items, "mul(");
    while (iter.next()) |slice| {
        if (!canDoOp(content.items[0 .. iter.index - slice.len])) {
            std.debug.print("  cannot do {s}\n", .{slice[0..@min(slice.len, 10)]});
            continue;
        }
        std.debug.print("\n", .{});
        var offset: usize = 0;
        var left: u32 = 0;
        var right: u32 = 0;

        offset = parseOperand(slice, &left) catch {
            continue;
        };

        if (offset + 1 >= slice.len or slice[offset] != ',') {
            continue;
        }
        offset += 1;
        offset += parseOperand(slice[offset..], &right) catch {
            continue;
        };

        if (offset >= slice.len or slice[offset] != ')') {
            continue;
        }

        total += left * right;
    }

    std.debug.print("total: {d}\n", .{total});
}
