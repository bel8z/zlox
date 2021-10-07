const std = @import("std");

const lox = @import("lox.zig");

pub fn main() anyerror!void {
    // Setup the main allocator (useful for debugging)
    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = &gpalloc.allocator;
    defer _ = gpalloc.deinit();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    var stdout = std.io.getStdOut().writer();

    switch (args.len) {
        1 => try lox.repl(alloc),
        2 => try lox.runFile(alloc, args[1]),
        else => {
            try stdout.print("Usage: lox [path]\n", .{});
            std.process.exit(64);
        },
    }
}
