const std = @import("std");

const CrossMasDirection = enum {
    top_down,
    left_right,
    right_left,
    bottom_up,
};

pub const Matrix = struct {
    line_length: usize,
    chars_in_line: usize,
    content: []const u8,

    pub fn init(slice: []const u8) !@This() {
        const new_line_idx = std.mem.indexOfScalar(u8, slice, '\n') orelse return error.MissingNewLine;

        return .{
            .chars_in_line = new_line_idx - @intFromBool(slice[new_line_idx - 1] == '\r'),
            .line_length = new_line_idx + 1,
            .content = slice,
        };
    }

    pub fn lines(self: @This()) usize {
        return @divTrunc(self.content.len + self.line_length - 1, self.line_length);
    }

    pub fn columns(self: @This()) usize {
        return self.chars_in_line;
    }

    pub fn charAt(self: @This(), line: usize, column: usize) ?u8 {
        if (line >= self.lines() or column >= self.columns())
            return null;

        return self.content[line * self.line_length + column];
    }

    pub fn countXmas(self: @This(), line: usize, column: usize) usize {
        var count: usize = 0;

        // east
        count += @intFromBool(self.isXmas(line, column, 0, 1));
        // southeast
        count += @intFromBool(self.isXmas(line, column, 1, 1));
        // south
        count += @intFromBool(self.isXmas(line, column, 1, 0));
        // southwest
        count += @intFromBool(self.isXmas(line, column, 1, -1));
        // west
        count += @intFromBool(self.isXmas(line, column, 0, -1));
        // northwest
        count += @intFromBool(self.isXmas(line, column, -1, -1));
        // north
        count += @intFromBool(self.isXmas(line, column, -1, 0));
        // northeast
        count += @intFromBool(self.isXmas(line, column, -1, 1));

        return count;
    }

    pub fn countCrossMas(self: @This(), line: usize, column: usize) usize {
        var count: usize = 0;

        count += @intFromBool(self.isCrossMas(line, column, .top_down));
        count += @intFromBool(self.isCrossMas(line, column, .left_right));
        count += @intFromBool(self.isCrossMas(line, column, .right_left));
        count += @intFromBool(self.isCrossMas(line, column, .bottom_up));

        return count;
    }

    fn isXmas(self: @This(), line: usize, column: usize, delta_line: i8, delta_columns: i8) bool {
        for ("XMAS", 0..) |expected_char, i| {
            const x = calculate(column, i, delta_columns) orelse return false;
            const y = calculate(line, i, delta_line) orelse return false;

            if (x >= self.columns() or y >= self.lines())
                return false;

            if (self.charAt(y, x) != expected_char)
                return false;
        }

        return true;
    }

    fn isCrossMas(self: @This(), line: usize, column: usize, direction: CrossMasDirection) bool {
        switch (direction) {
            .top_down => {
                return self.charAt(line, column) == 'M' and
                    self.charAt(line, column + 2) == 'M' and
                    self.charAt(line + 1, column + 1) == 'A' and
                    self.charAt(line + 2, column) == 'S' and
                    self.charAt(line + 2, column + 2) == 'S';
            },
            .left_right => {
                return self.charAt(line, column) == 'M' and
                    self.charAt(line, column + 2) == 'S' and
                    self.charAt(line + 1, column + 1) == 'A' and
                    self.charAt(line + 2, column) == 'M' and
                    self.charAt(line + 2, column + 2) == 'S';
            },
            .bottom_up => {
                return self.charAt(line, column) == 'M' and
                    self.charAt(line, column + 2) == 'M' and
                    self.charAt(line -% 1, column + 1) == 'A' and
                    self.charAt(line -% 2, column) == 'S' and
                    self.charAt(line -% 2, column + 2) == 'S';
            },
            .right_left => {
                return self.charAt(line, column) == 'M' and
                    self.charAt(line, column -% 2) == 'S' and
                    self.charAt(line -% 1, column -% 1) == 'A' and
                    self.charAt(line -% 2, column) == 'M' and
                    self.charAt(line -% 2, column -% 2) == 'S';
            },
        }
    }

    fn calculate(base: usize, times: usize, delta: i8) ?usize {
        const offset = (std.math.cast(isize, times) orelse return null) * delta;

        if (offset > 0)
            return base + (std.math.cast(usize, offset) orelse return null);

        return std.math.sub(usize, base, std.math.cast(usize, -offset) orelse return null) catch null;
    }
};

pub fn execute() !void {
    var file = try std.fs.cwd().openFile("data/day-04.txt", .{});
    defer file.close();

    var reader = file.reader();
    var content = std.ArrayList(u8).init(std.heap.page_allocator);
    defer content.deinit();

    try reader.readAllArrayList(
        &content,
        std.math.maxInt(usize),
    );
    const matrix = try Matrix.init(content.items);

    var total: usize = 0;
    for (0..matrix.lines()) |line| {
        for (0..matrix.columns()) |column| {
            if (matrix.charAt(line, column) != 'M')
                continue;

            total += matrix.countCrossMas(line, column);
        }
    }

    std.debug.print("total: {d}\n", .{total});
}
