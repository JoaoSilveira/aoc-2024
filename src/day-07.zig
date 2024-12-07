const std = @import("std");

const Equation = struct {
    answer: u64,
    operands: []u64,
};

const InputData = struct {
    equations: []Equation,
    alloc: std.mem.Allocator,

    pub fn deinit(self: @This()) void {
        self.alloc.free(self.equations);
    }
};

fn readInput() !InputData {
    var file = try std.fs.cwd().openFile("data/day-07.txt", .{});
    defer file.close();

    var reader = file.reader();
    var content = std.ArrayList(u8).init(std.heap.page_allocator);
    defer content.deinit();

    try reader.readAllArrayList(
        &content,
        std.math.maxInt(usize),
    );

    var numbers = std.ArrayList(u64).init(std.heap.page_allocator);
    errdefer numbers.deinit();

    var equations = std.ArrayList(Equation).init(std.heap.page_allocator);
    errdefer equations.deinit();

    var line_iter = std.mem.splitSequence(u8, content.items, "\r\n");
    while (line_iter.next()) |line| {
        var number_iter = std.mem.splitScalar(u8, line, ' ');
        while (number_iter.next()) |number| {
            const parsed = try std.fmt.parseInt(
                u64,
                number[0 .. number.len - @intFromBool(number[number.len - 1] == ':')],
                10,
            );

            try numbers.append(parsed);
        }

        var slice = try numbers.toOwnedSlice();
        try equations.append(Equation{
            .answer = slice[0],
            .operands = slice[1..],
        });
    }

    return InputData{
        .alloc = std.heap.page_allocator,
        .equations = try equations.toOwnedSlice(),
    };
}

fn firstHalf(input: InputData) !void {
    var total: u64 = 0;

    eq_loop: for (input.equations) |equation| {
        const max = try std.math.shlExact(u32, 1, @truncate(equation.operands.len - 1));

        for (0..max) |flags| {
            var sum: u64 = equation.operands[0];

            for (equation.operands[1..], 0..) |op, bit| {
                if ((flags & std.math.shl(u32, 1, bit)) != 0) {
                    sum *= op;
                } else {
                    sum += op;
                }
            }

            if (sum == equation.answer) {
                total += sum;
                continue :eq_loop;
            }
        }
    }

    std.debug.print("total: {d}\n", .{total});
}

const Op = enum {
    sum,
    mul,
    concat,

    pub fn nextOp(self: @This()) ?@This() {
        return switch (self) {
            .sum => .mul,
            .mul => .concat,
            .concat => null,
        };
    }
};

const OpCombination = struct {
    ops: [16]Op = [_]Op{.sum} ** 16,

    pub fn next(self: *@This()) void {
        for (&self.ops) |*op| {
            if (op.nextOp()) |next_op| {
                op.* = next_op;
                break;
            }

            // wraps to sum
            op.* = .sum;
        }
    }
};

fn secondHalf(input: InputData) !void {
    var total: u64 = 0;

    eq_loop: for (input.equations) |equation| {
        const max = std.math.pow(u64, 3, equation.operands.len - 1);

        var op_combination = OpCombination{};
        for (0..max) |_| {
            defer op_combination.next();
            var sum: u64 = equation.operands[0];

            for (equation.operands[1..], 0..) |op, index| {
                switch (op_combination.ops[index]) {
                    .sum => sum += op,
                    .mul => sum *= op,
                    .concat => {
                        var magnetude: u64 = 10;
                        while (magnetude <= op) : (magnetude *= 10) {}

                        sum = sum * magnetude + op;
                    },
                }
            }

            if (sum == equation.answer) {
                total += sum;
                continue :eq_loop;
            }
        }
    }

    std.debug.print("total: {d}\n", .{total});
}

pub fn execute() !void {
    const input = try readInput();
    defer input.deinit();

    try secondHalf(input);
}
