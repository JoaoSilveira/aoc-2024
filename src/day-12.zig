const std = @import("std");

const Side = packed struct {
    top: bool,
    right: bool,
    bottom: bool,
    left: bool,
};

const Position = struct {
    x: usize,
    y: usize,

    fn eql(self: @This(), other: @This()) bool {
        return self.x == other.x and self.y == other.y;
    }

    fn up(self: @This()) ?@This() {
        if (self.y == 0) return null;

        return @This(){
            .x = self.x,
            .y = self.y - 1,
        };
    }

    fn down(self: @This(), limit: usize) ?@This() {
        if (self.y + 1 >= limit) return null;

        return @This(){
            .x = self.x,
            .y = self.y + 1,
        };
    }

    fn left(self: @This()) ?@This() {
        if (self.x == 0) return null;

        return @This(){
            .x = self.x - 1,
            .y = self.y,
        };
    }

    fn right(self: @This(), limit: usize) ?@This() {
        if (self.x + 1 >= limit) return null;

        return @This(){
            .x = self.x + 1,
            .y = self.y,
        };
    }

    fn nw(self: @This()) ?@This() {
        return if (self.left()) |l| l.up() else null;
    }

    fn ne(self: @This(), columns: usize) ?@This() {
        return if (self.right(columns)) |r| r.up() else null;
    }

    fn sw(self: @This(), lines: usize) ?@This() {
        return if (self.left()) |l| l.down(lines) else null;
    }

    fn se(self: @This(), lines: usize, columns: usize) ?@This() {
        return if (self.right(columns)) |r| r.up(lines) else null;
    }
};

const AreaPerimeter = struct {
    area: u32,
    perimeter: u32,
};

pub const Matrix = struct {
    line_length: usize,
    chars_in_line: usize,
    content: []u8,

    pub fn lines(self: @This()) usize {
        return @divTrunc(self.content.len + self.line_length - 1, self.line_length);
    }

    pub fn columns(self: @This()) usize {
        return self.chars_in_line;
    }

    pub fn charAt(self: @This(), pos: Position) ?u8 {
        self.checkInsideBounds(pos) catch return null;

        return self.content[self.posOffset(pos).?];
    }

    pub fn charAtMaybe(self: @This(), m_pos: ?Position) ?u8 {
        if (m_pos) |pos| {
            return self.charAt(pos);
        }

        return null;
    }

    pub fn posOffset(self: @This(), pos: Position) ?usize {
        self.checkInsideBounds(pos) catch return null;

        return pos.y * self.line_length + pos.x;
    }

    pub fn offsetToPos(self: @This(), offset: usize) ?Position {
        if (offset >= self.content.len) return null;

        const pos = Position{
            .y = @divTrunc(offset, self.line_length),
            .x = offset % self.line_length,
        };

        return if (self.checkInsideBounds(pos)) pos else |_| null;
    }

    fn checkInsideBounds(self: @This(), pos: Position) !void {
        if (pos.y >= self.lines() or pos.x >= self.columns())
            return error.OutOfBounds;
    }
};

const InputData = struct {
    alloc: std.mem.Allocator,
    map: Matrix,

    pub fn deinit(self: @This()) void {
        self.alloc.free(self.map.content);
    }
};

fn parseInput() !InputData {
    var file = try std.fs.cwd().openFile("data/day-12.txt", .{});
    defer file.close();

    var reader = file.reader();
    var content = std.ArrayList(u8).init(std.heap.page_allocator);
    defer content.deinit();

    try reader.readAllArrayList(
        &content,
        std.math.maxInt(usize),
    );

    const mat = Matrix{
        .line_length = 1 + (std.mem.indexOfScalar(u8, content.items, '\n') orelse return error.InvalidInput),
        .chars_in_line = std.mem.indexOfAny(u8, content.items, "\r\n") orelse return error.InvalidInput,
        .content = try content.toOwnedSlice(),
    };

    return InputData{
        .alloc = std.heap.page_allocator,
        .map = mat,
    };
}

fn sidesOf(map: Matrix, pos: Position) Side {
    const flower = map.charAt(pos).?;
    var sides = Side{ .top = false, .right = false, .bottom = false, .left = false };

    if (pos.left()) |l| {
        sides.left = map.charAt(l) != flower;
    } else {
        sides.left = true;
    }

    if (pos.right(map.columns())) |r| {
        sides.right = map.charAt(r) != flower;
    } else {
        sides.right = true;
    }

    if (pos.up()) |t| {
        sides.top = map.charAt(t) != flower;
    } else {
        sides.top = true;
    }

    if (pos.down(map.lines())) |b| {
        sides.bottom = map.charAt(b) != flower;
    } else {
        sides.bottom = true;
    }

    return sides;
}

fn perimeterOf(map: Matrix, pos: Position) u32 {
    const flower = map.charAt(pos).?;
    var perim: u32 = 0;

    if (pos.left()) |l| {
        perim += @intFromBool(map.charAt(l) != flower);
    } else {
        perim += 1;
    }

    if (pos.right(map.columns())) |r| {
        perim += @intFromBool(map.charAt(r) != flower);
    } else {
        perim += 1;
    }

    if (pos.up()) |t| {
        perim += @intFromBool(map.charAt(t) != flower);
    } else {
        perim += 1;
    }

    if (pos.down(map.lines())) |b| {
        perim += @intFromBool(map.charAt(b).? != flower);
    } else {
        perim += 1;
    }

    return perim;
}

fn calculateAreaAndPerimeter(map: Matrix, visited: *std.DynamicBitSet, pos: Position) AreaPerimeter {
    if (visited.isSet(pos.y * map.columns() + pos.x))
        return .{ .area = 0, .perimeter = 0 };

    const flower = map.charAt(pos).?;
    var areaPerim = AreaPerimeter{
        .area = 1,
        .perimeter = perimeterOf(map, pos),
    };

    visited.set(pos.y * map.columns() + pos.x);

    if (pos.right(map.columns())) |r| {
        if (map.charAt(r) == flower) {
            const r_data = calculateAreaAndPerimeter(map, visited, r);
            areaPerim.area += r_data.area;
            areaPerim.perimeter += r_data.perimeter;
        }
    }

    if (pos.down(map.lines())) |d| {
        if (map.charAt(d) == flower) {
            const d_data = calculateAreaAndPerimeter(map, visited, d);
            areaPerim.area += d_data.area;
            areaPerim.perimeter += d_data.perimeter;
        }
    }

    if (pos.left()) |l| {
        if (map.charAt(l) == flower) {
            const l_data = calculateAreaAndPerimeter(map, visited, l);
            areaPerim.area += l_data.area;
            areaPerim.perimeter += l_data.perimeter;
        }
    }

    if (pos.up()) |u| {
        if (map.charAt(u) == flower) {
            const u_data = calculateAreaAndPerimeter(map, visited, u);
            areaPerim.area += u_data.area;
            areaPerim.perimeter += u_data.perimeter;
        }
    }

    return areaPerim;
}

const Border = struct {
    sides: Side,
    pos: Position,
};

const Line = struct {
    start: Position,
    end: Position,
    border_direction: Direction,
};

const ShapeBorders = struct {
    lines: std.ArrayList(Line),

    fn findLineIndex(self: @This(), m_pos: ?Position, border_direction: Direction) ?usize {
        if (m_pos) |pos| {
            for (self.lines.items, 0..) |line, i| {
                if (line.border_direction != border_direction)
                    continue;

                if (pos.eql(line.start) or pos.eql(line.end))
                    return i;
            }
        }

        return null;
    }

    pub fn mergePos(self: *@This(), map: Matrix, pos: Position, border_direction: Direction) bool {
        const start_index = switch (border_direction) {
            .up, .down => self.findLineIndex(pos.left(), border_direction),
            .left, .right => self.findLineIndex(pos.up(), border_direction),
        };
        const end_index = switch (border_direction) {
            .up, .down => self.findLineIndex(pos.right(map.columns()), border_direction),
            .left, .right => self.findLineIndex(pos.down(map.lines()), border_direction),
        };

        if (start_index) |si| {
            if (end_index) |ei| {
                self.lines.items[si].end = self.lines.items[ei].end;
                _ = self.lines.swapRemove(ei);
                return true;
            }

            self.lines.items[si].end = pos;
            return true;
        }

        if (end_index) |ei| {
            self.lines.items[ei].start = pos;
            return true;
        }

        return false;
    }

    pub fn add(self: *@This(), map: Matrix, pos: Position, sides: Side) !void {
        if (sides.top and !self.mergePos(map, pos, .up))
            try self.lines.append(.{ .start = pos, .end = pos, .border_direction = .up });

        if (sides.bottom and !self.mergePos(map, pos, .down))
            try self.lines.append(.{ .start = pos, .end = pos, .border_direction = .down });

        if (sides.left and !self.mergePos(map, pos, .left))
            try self.lines.append(.{ .start = pos, .end = pos, .border_direction = .left });

        if (sides.right and !self.mergePos(map, pos, .right))
            try self.lines.append(.{ .start = pos, .end = pos, .border_direction = .right });
    }
};

fn calculateArea(
    map: Matrix,
    visited: *std.DynamicBitSet,
    border: *ShapeBorders,
    pos: Position,
) !u64 {
    if (visited.isSet(pos.y * map.columns() + pos.x))
        return 0;

    visited.set(pos.y * map.columns() + pos.x);

    if (perimeterOf(map, pos) > 0)
        try border.add(map, pos, sidesOf(map, pos));

    const flower = map.charAt(pos);
    var area: u64 = 1;
    if (pos.right(map.columns())) |r| {
        if (map.charAt(r) == flower) {
            area += try calculateArea(map, visited, border, r);
        }
    }

    if (pos.down(map.lines())) |d| {
        if (map.charAt(d) == flower) {
            area += try calculateArea(map, visited, border, d);
        }
    }

    if (pos.left()) |l| {
        if (map.charAt(l) == flower) {
            area += try calculateArea(map, visited, border, l);
        }
    }

    if (pos.up()) |u| {
        if (map.charAt(u) == flower) {
            area += try calculateArea(map, visited, border, u);
        }
    }

    return area;
}

const Direction = enum {
    up,
    right,
    down,
    left,
};

fn existsBorder(borders: std.ArrayList(Border), pos: Position, border_dir: Direction) bool {
    for (borders.items) |b| {
        if (!b.pos.eql(pos))
            continue;

        return switch (border_dir) {
            .up => b.sides.top,
            .right => b.sides.right,
            .down => b.sides.bottom,
            .left => b.sides.left,
        };
    }

    return false;
}

fn firstHalf(input: *InputData) !void {
    var visitedList = try std.DynamicBitSet.initEmpty(input.alloc, input.map.lines() * input.map.columns());
    defer visitedList.deinit();

    var cost: u64 = 0;
    for (0..input.map.lines()) |line| {
        for (0..input.map.columns()) |column| {
            if (visitedList.isSet(line * input.map.columns() + column))
                continue;

            const pos = Position{ .y = line, .x = column };
            const areaPerim = calculateAreaAndPerimeter(input.map, &visitedList, pos);

            cost += areaPerim.area * areaPerim.perimeter;
        }
    }

    std.debug.print("cost: {d}\n", .{cost});
}

fn secondHalf(input: *InputData) !void {
    var visitedList = try std.DynamicBitSet.initEmpty(input.alloc, input.map.lines() * input.map.columns());
    defer visitedList.deinit();
    var borders = ShapeBorders{ .lines = std.ArrayList(Line).init(std.heap.page_allocator) };
    defer borders.lines.deinit();

    var cost: u64 = 0;
    for (0..input.map.lines()) |line| {
        for (0..input.map.columns()) |column| {
            if (visitedList.isSet(line * input.map.columns() + column))
                continue;

            borders.lines.clearRetainingCapacity();
            const pos = Position{ .y = line, .x = column };
            const area = try calculateArea(input.map, &visitedList, &borders, pos);
            const sides = borders.lines.items.len; //calculateSides(input.map, &borders);

            cost += area * sides;
        }
    }

    std.debug.print("cost: {d}\n", .{cost});
}

pub fn execute() !void {
    var input = try parseInput();
    defer input.deinit();

    try secondHalf(&input);
}
