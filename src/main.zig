const std = @import("std");

const Interpreter = @import("Interpreter.zig");

pub fn main() anyerror!void {
    // Setup the main allocator (useful for debugging)
    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpalloc.allocator();
    defer _ = gpalloc.deinit();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    var stdout = std.io.getStdOut().writer();

    var lox = try Interpreter.init(alloc);
    defer lox.deinit();

    switch (args.len) {
        1 => try lox.repl(),
        2 => try lox.runFile(args[1]),
        else => {
            try stdout.print("Usage: lox [path]\n", .{});
            std.process.exit(64);
        },
    }
}
