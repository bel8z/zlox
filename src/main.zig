const std = @import("std");
const fs = std.fs;

pub fn main() anyerror!void {
    // Setup the main allocator (useful for debugging)
    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = &gpalloc.allocator;
    defer _ = gpalloc.deinit();

    var f = try fs.openFileAbsolute("C:/temp/03111588.txt", .{ .read = true });
    defer f.close();

    var buf: [1024]u8 = undefined;
    var bytes_read = try f.read(buf[0..]);

    const stdout = std.io.getStdOut().writer();

    while (bytes_read > 0) {
        try stdout.print("{s}", .{buf[0..bytes_read]});
        bytes_read = try f.read(buf[0..]);
    }

    std.log.info("All your codebase are belong to us.", .{});
}
