const std = @import("std");
const mem = std.mem;
const io = std.io;

const max_size = 1024 * 1024 * 1024;

var had_error = false;

pub fn repl(allocator: *mem.Allocator) !void {
    var stdin = io.bufferedReader(io.getStdIn().reader()).reader();
    var stdout = io.getStdOut().writer();

    while (true) {
        try stdout.print("> ", .{});

        // TODO (Matteo): Better allocation strategy
        var maybe_line = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', max_size);
        if (maybe_line) |line| {
            defer allocator.free(line);
            try run(allocator, line);
        } else {
            break;
        }

        had_error = false;
    }
}

pub fn runFile(allocator: *mem.Allocator, filename: []u8) !void {
    var file = try std.fs.openFileAbsolute(filename, .{ .read = true });
    var bytes = try file.readToEndAlloc(allocator, max_size);
    try run(allocator, bytes);
    if (had_error) std.process.exit(65);
}

pub fn reportError(line: usize, message: []u8) !void {
    had_error = true;
    try report(line, "", message);
}

pub fn report(line: usize, where: []u8, message: []u8) !void {
    try std.io.getStdErr().writer().print("[line {}] Error{}: {}", .{ line, where, message });
}

fn run(allocator: *mem.Allocator, bytes: []u8) !void {
    var scanner = Scanner.init(allocator, bytes);
    var tokens = try scanner.scanTokens();
    var stdout = io.getStdOut().writer();

    for (tokens.items) |token| {
        try stdout.print("{}\n", .{token});
    }
}

const List = std.ArrayList;
const Token = struct { id: i32 };

const Scanner = struct {
    const Self = @This();

    allocator: *mem.Allocator,
    bytes: []u8,

    fn init(allocator: *mem.Allocator, bytes: []u8) Self {
        return Self{ .allocator = allocator, .bytes = bytes };
    }

    fn scanTokens(self: *Self) !List(Token) {
        return List(Token).init(self.allocator);
    }
};
