const std = @import("std");

const exercise = @import("./day-07.zig");

pub fn main() void {
    exercise.execute() catch |err| {
        std.log.err("Failed. Error: {s}", .{@errorName(err)});
    };
}
