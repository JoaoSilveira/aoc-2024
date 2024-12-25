const std = @import("std");

const OpCode = struct {
    const ADV = 0;
    const BXL = 1;
    const BST = 2;
    const JNZ = 3;
    const BXC = 4;
    const OUT = 5;
    const BDV = 6;
    const CDV = 7;
};

const Computer = struct {
    a: u64,
    b: u64,
    c: u64,
    ip: usize,
    mem: []u8,

    fn tick(self: *@This()) !?u8 {
        if (self.ip >= self.mem.len)
            return error.Halt;

        // std.debug.print("a: {d} b: {d} c: {d} || op: {d} lit: {d} com: {d}\n", .{
        //     self.a,        self.b,             self.c,
        //     self.readOp(), self.readLiteral(), self.readCombo(),
        // });

        switch (self.readOp()) {
            OpCode.ADV => {
                const pow = try std.math.powi(u64, 2, self.readCombo());
                self.a = @divTrunc(self.a, pow);
                self.ip += 2;
            },
            OpCode.BXL => {
                self.b = @as(u8, @intCast(self.b)) ^ self.readLiteral();
                self.ip += 2;
            },
            OpCode.BST => {
                self.b = self.readCombo() % 8;
                self.ip += 2;
            },
            OpCode.JNZ => {
                if (self.a != 0) {
                    self.ip = self.readLiteral();
                } else {
                    self.ip += 2;
                }
            },
            OpCode.BXC => {
                self.b = self.b ^ self.c;
                self.ip += 2;
            },
            OpCode.OUT => {
                const out_value = self.readCombo() % 8;
                self.ip += 2;

                return @as(u8, @intCast(out_value));
            },
            OpCode.BDV => {
                const pow = try std.math.powi(u64, 2, self.readCombo());
                self.b = @divTrunc(self.a, pow);
                self.ip += 2;
            },
            OpCode.CDV => {
                const pow = try std.math.powi(u64, 2, self.readCombo());
                self.c = @divTrunc(self.a, pow);
                self.ip += 2;
            },
            else => return error.InvalidOpCode,
        }

        return null;
    }

    fn readOp(self: @This()) u8 {
        return self.mem[self.ip];
    }

    fn readLiteral(self: @This()) u8 {
        return self.mem[self.ip + 1];
    }

    fn readCombo(self: @This()) u64 {
        return switch (self.readLiteral()) {
            0...3 => |b| @as(u64, b),
            4 => self.a,
            5 => self.b,
            6 => self.c,
            else => @panic("INVALID PROGRAM"),
        };
    }
};

const InputData = struct {
    alloc: std.mem.Allocator,

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

        return @This(){
            .alloc = std.heap.page_allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

fn firstHalf(input: *InputData) !void {
    _ = input;

    var mem = [_]u8{
        2, 4,
        1, 3,
        7, 5,
        1, 5,
        0, 3,
        4, 1,
        5, 5,
        3, 0,
    };
    var computer = Computer{
        .a = 23035799752301,
        .b = 0,
        .c = 0,
        .ip = 0,
        .mem = mem[0..],
    };

    while (true) {
        const val = computer.tick() catch |err| {
            if (err == error.Halt)
                break;

            return err;
        };

        if (val) |v| {
            std.debug.print("{d},", .{v});
        }
    }

    std.debug.print("\n", .{});
}

// BST A
// BXL 3
// CDV B
// BXL 5
// ADV 3
// BXC _
// OUT B
// JNZ 0

// b = a % 8
// b = b ^ 3
// c = a / (2 ** b)
// b = b ^ 5
// a = a / 8
// b = b ^ c
// out b
// jnz 0

fn secondHalf(input: *InputData) !void {
    _ = input;

    var mem = [_]u8{
        2, 4,
        1, 3,
        7, 5,
        1, 5,
        0, 3,
        4, 1,
        5, 5,
        3, 0,
    };

    // var start_a: u64 = 0b000;
    // const start_a = 0b010_111_111;
    // const Pair = struct {
    //     value: u64,
    //     bits: u64,
    // };

    // var candidate_list = std.ArrayList(Pair).init(input.alloc);
    // defer candidate_list.deinit();

    // try candidate_list.append(.{ .value = 0, .bits = 0 });

    // while (candidate_list.items.len > 0) {
    //     const pair = candidate_list.orderedRemove(0);
    //     const max_index = @divTrunc(pair.bits, 3) + 1;

    //     const candidate = pair.value;
    //     std.debug.print("took: {d}\n", .{candidate});

    //     for (0..4096) |i| {
    //         const start_a: u64 = pair.value + std.math.shl(u64, i, pair.bits);
    //         var computer = Computer{
    //             .a = start_a,
    //             .b = 0,
    //             .c = 0,
    //             .ip = 0,
    //             .mem = mem[0..],
    //         };

    //         var out_index: usize = 0;
    //         while (true) {
    //             const output = computer.tick() catch break;

    //             if (output) |value| {
    //                 if (value != mem[out_index])
    //                     break;

    //                 out_index += 1;
    //                 if (out_index > max_index) {
    //                     const new_candidate = start_a % std.math.shl(u64, 1, pair.bits + 3);
    //                     const exists_candidate = exists_lbl: {
    //                         for (candidate_list.items) |p| {
    //                             if (p.value == new_candidate)
    //                                 break :exists_lbl true;
    //                         }
    //                         break :exists_lbl false;
    //                     };

    //                     if (!exists_candidate) {
    //                         std.debug.print("c: {b}\n", .{new_candidate});
    //                         try candidate_list.append(.{
    //                             .value = new_candidate,
    //                             .bits = pair.bits + 3,
    //                         });
    //                     }
    //                     break;
    //                 }

    //                 if (out_index >= mem.len) {
    //                     var cpu = Computer{
    //                         .a = start_a,
    //                         .b = 0,
    //                         .c = 0,
    //                         .ip = 0,
    //                         .mem = mem[0..],
    //                     };
    //                     var cmp_i: usize = 0;

    //                     while (true) {
    //                         if (cpu.tick()) |v| {
    //                             if (cmp_i >= mem.len or v != mem[cmp_i])
    //                                 break;

    //                             cmp_i += 1;
    //                         } else |err| {
    //                             if (err == error.Halt)
    //                                 std.debug.print("value: {d}\n", .{start_a});
    //                         }
    //                     }
    //                     break;
    //                 }
    //             }
    //         }
    //     }
    // }

    const start_a = 5443613707885;
    for (0..8) |i| {
        var computer = Computer{
            .a = start_a + (i << (15 * 3)),
            .b = 0,
            .c = 0,
            .ip = 0,
            .mem = mem[0..],
        };

        std.debug.print("sa: {d} at {b} = ", .{ computer.a, computer.a });
        while (true) {
            const out_value = computer.tick() catch break;

            if (out_value) |value| {
                std.debug.print("{d} ", .{value});
                // if (mem[ip_index] != value)
                //     break;

                // ip_index += 1;
                // if (ip_index == mem.len) {
                //     std.debug.print("\na: {d}\n", .{start_a});
                //     return;
                // }
                // if (ip_index == 2) {
                //     std.debug.print("sa: {d} - {d}\n", .{ start_a, value });
                // }
            }
        }
        std.debug.print("\n", .{});
        // std.debug.print("\n", .{});
        // start_a = std.math.add(u64, start_a, 1) catch break;
    }
}

pub fn execute() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.print("{s}\n", .{@tagName(gpa.deinit())});

    var input_data = try InputData.parse(gpa.allocator(), "data/day-17.txt");
    defer input_data.deinit();

    try secondHalf(&input_data);
}
