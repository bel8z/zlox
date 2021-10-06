const std = @import("std");
const fs = std.fs;

pub fn main() anyerror!void {
    // Setup the main allocator (useful for debugging)
    // var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    // var alloc = &gpalloc.allocator;
    // defer _ = gpalloc.deinit();

    // const stdout = std.io.getStdOut().writer();

    // var reader = std.io.bufferedReader(f.reader()).reader();
    // while (true) {
    //     var maybe_line = try reader.readUntilDelimiterOrEof(buf[0..], '\n');
    //     if (maybe_line) |line| {
    //         try stdout.print("{s}", .{line});
    //     }
    // }
}
