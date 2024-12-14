const std = @import("std");
const empty_block = std.math.maxInt(u16);

const InputData = struct {
    alloc: std.mem.Allocator,
    input: []u8,
    fs: []u16,

    pub fn deinit(self: @This()) void {
        self.alloc.free(self.input);
    }
};

fn parseInput() !InputData {
    var file = try std.fs.cwd().openFile("data/day-09.txt", .{});
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
        .fs = &[_]u16{},
    };
}

fn decodeDisk(alloc: std.mem.Allocator, input: []const u8) ![]u16 {
    var list = std.ArrayList(u16).init(alloc);
    defer list.deinit();

    var is_file = true;
    var file_id: u16 = 0;
    for (input) |digit| {
        const quantity = digit - '0';

        if (is_file) {
            try list.appendNTimes(file_id, quantity);
            file_id += 1;
        } else {
            try list.appendNTimes(empty_block, quantity);
        }

        is_file = !is_file;
    }

    return try list.toOwnedSlice();
}

fn lastFile(fs: []u16, index: usize) ?usize {
    var i: usize = index;
    while (i > 0) {
        i -= 1;
        if (fs[i] != empty_block) return i;
    }

    return null;
}

fn lastFileSpace(fs: []u16, index: usize) ?Space {
    const end_index = lastFile(fs, index) orelse return null;
    var i = end_index;
    while (i > 0) {
        i -= 1;
        if (fs[i] != fs[end_index])
            return Space{
                .index = i + 1,
                .len = end_index - i,
            };
    }

    return Space{
        .index = 0,
        .len = end_index + 1,
    };
}

const Space = struct {
    index: usize,
    len: usize,
};
fn nextEmptySpace(fs: []u16, index: usize) ?Space {
    var i = std.mem.indexOfScalarPos(
        u16,
        fs,
        index,
        empty_block,
    ) orelse return null;
    var space = Space{
        .index = i,
        .len = 0,
    };
    while (i < fs.len) : (i += 1) {
        if (fs[i] != empty_block) break;
    }

    space.len = i - space.index;
    return space;
}

fn diskDefragUnit(fs: []u16) void {
    var end_index = lastFile(fs, fs.len) orelse return;

    for (fs, 0..) |*file_id, i| {
        if (i >= end_index) break;

        if (file_id.* == empty_block) {
            file_id.* = fs[end_index];
            fs[end_index] = empty_block;

            end_index = lastFile(fs, end_index) orelse return;
        }
    }
}

fn diskDefragWhole(fs: []u16) void {
    var last_file = lastFileSpace(fs, fs.len) orelse return;

    while (true) {
        var m_empty = nextEmptySpace(fs, 0);
        while (m_empty) |empty| {
            if (empty.index > last_file.index) {
                m_empty = null;
                break;
            }
            if (empty.len >= last_file.len) break;
            m_empty = nextEmptySpace(fs, empty.index + empty.len);
        }

        if (m_empty) |empty| {
            for (fs[empty.index .. empty.index + last_file.len]) |*block| {
                block.* = fs[last_file.index];
            }

            for (fs[last_file.index .. last_file.index + last_file.len]) |*block| {
                block.* = empty_block;
            }
        }

        if (lastFileSpace(fs, last_file.index)) |new_last| {
            last_file = new_last;
        } else {
            break;
        }
    }
}

fn fsChecksum(fs: []const u16) u64 {
    var checksum: u64 = 0;
    for (fs, 0..) |id, i| {
        switch (id) {
            empty_block => {},
            else => checksum += id * i,
        }
    }

    return checksum;
}

fn firstHalf(input: *InputData) !void {
    input.fs = try decodeDisk(input.alloc, input.input);
    diskDefragUnit(input.fs);

    std.debug.print("{d}\n", .{fsChecksum(input.fs)});
}

fn secondHalf(input: *InputData) !void {
    input.fs = try decodeDisk(input.alloc, input.input);
    diskDefragWhole(input.fs);

    std.debug.print("{d}\n", .{fsChecksum(input.fs)});
}

pub fn execute() !void {
    var input = try parseInput();
    defer input.deinit();

    try secondHalf(&input);
}
