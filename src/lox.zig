// Standard imports
const std = @import("std");
const mem = std.mem;
const io = std.io;
const List = std.ArrayList;

pub const assert = std.debug.assert;

pub const Token = _token.Token;
pub const TokenType = _token.TokenType;
pub const Literal = _token.Literal;
const _token = @import("token.zig");

const Scanner = @import("scanner.zig").Scanner;

pub const ast = @import("ast.zig");

// Constants
const max_size = 1024 * 1024 * 1024;

pub const Lox = struct {
    const Self = @This();

    had_error: bool,
    allocator: mem.Allocator,
    stderr: std.fs.File.Writer,
    keywords: std.StringHashMap(TokenType),

    //=== Init / deinit ===//

    pub fn init(allocator: mem.Allocator) !Self {
        return Self{
            .had_error = false,
            .allocator = allocator,
            .stderr = io.getStdErr().writer(),
            .keywords = try buildKeywordMap(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.keywords.deinit();
    }

    //=== Main interpreter loops ===//

    pub fn repl(self: *Self) !void {
        var stdin = io.bufferedReader(io.getStdIn().reader()).reader();
        var stdout = io.getStdOut().writer();

        while (true) {
            try stdout.print("> ", .{});

            // TODO (Matteo): Better allocation strategy
            var maybe_line = try stdin.readUntilDelimiterOrEofAlloc(self.allocator, '\n', max_size);
            if (maybe_line) |line| {
                defer self.allocator.free(line);
                try self.run(line);
            } else {
                break;
            }

            self.had_error = false;
        }
    }

    pub fn runFile(self: *Self, filename: []u8) !void {
        var file = try std.fs.openFileAbsolute(filename, .{ .read = true });
        var bytes = try file.readToEndAlloc(self.allocator, max_size);

        try self.run(bytes);

        if (self.had_error) std.process.exit(65);
    }

    fn run(self: *Self, source: []u8) !void {
        var scanner = Scanner.init(self, source);

        // TODO (Matteo): Is a list really needed? Maybe for later parsing
        var tokens = List(Token).init(self.allocator);
        defer tokens.deinit();

        var stdout = io.getStdOut().writer();

        while (scanner.scanToken()) |token| {
            try tokens.append(token);
            try stdout.print("{}\n", .{token});
        }
    }

    //=== Reporting ===//

    pub fn reportError(self: *Self, line: usize, comptime format: []const u8, args: anytype) void {
        self.had_error = true;
        self.report(line, "", format, args);
    }

    pub fn report(self: *Self, line: usize, where: []u8, comptime format: []const u8, args: anytype) void {
        // TODO (Matteo): Better error handling?
        // Maybe but at the moment I don't want to bother if writing to stderr fails.
        // We are a CLI interpreter after all.

        self.stderr.print("[line {}] Error{s}: ", .{ line, where }) catch unreachable;
        self.stderr.print(format, args) catch unreachable;
        self.stderr.print("\n", .{}) catch unreachable;
    }
};

fn buildKeywordMap(allocator: mem.Allocator) !std.StringHashMap(TokenType) {
    var map = std.StringHashMap(TokenType).init(allocator);
    errdefer map.deinit();

    try map.put("and", .AND);
    try map.put("class", .CLASS);
    try map.put("else", .ELSE);
    try map.put("false", .FALSE);
    try map.put("for", .FOR);
    try map.put("fun", .FUN);
    try map.put("if", .IF);
    try map.put("nil", .NIL);
    try map.put("or", .OR);
    try map.put("print", .PRINT);
    try map.put("return", .RETURN);
    try map.put("super", .SUPER);
    try map.put("this", .THIS);
    try map.put("true", .TRUE);
    try map.put("var", .VAR);
    try map.put("while", .WHILE);

    return map;
}
