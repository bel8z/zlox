// Standard imports
const std = @import("std");
const mem = std.mem;
const io = std.io;
const List = std.ArrayList;

pub const Token = _token.Token;
pub const TokenType = _token.TokenType;
pub const Literal = _token.Literal;
const _token = @import("token.zig");

pub const KeywordMap = std.StringHashMap(TokenType);

const Scanner = @import("scanner.zig").Scanner;

// Constants
const max_size = 1024 * 1024 * 1024;

//=== Main interpreter loops ===//

// TODO (Matteo): Improve this
var had_error = false;

pub fn repl(allocator: *mem.Allocator) !void {
    var stdin = io.bufferedReader(io.getStdIn().reader()).reader();
    var stdout = io.getStdOut().writer();

    var keys = try keywords(allocator);
    defer keys.deinit();

    while (true) {
        try stdout.print("> ", .{});

        // TODO (Matteo): Better allocation strategy
        var maybe_line = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', max_size);
        if (maybe_line) |line| {
            defer allocator.free(line);
            try run(allocator, line, &keys);
        } else {
            break;
        }

        had_error = false;
    }
}

pub fn runFile(allocator: *mem.Allocator, filename: []u8) !void {
    var file = try std.fs.openFileAbsolute(filename, .{ .read = true });
    var bytes = try file.readToEndAlloc(allocator, max_size);

    var keys = try keywords(allocator);
    defer keys.deinit();

    try run(allocator, bytes, &keys);

    if (had_error) std.process.exit(65);
}

fn run(allocator: *mem.Allocator, bytes: []u8, keys: *KeywordMap) !void {
    var stdout = io.getStdOut().writer();

    var scanner = Scanner.init(bytes, keys);

    // TODO (Matteo): Is a list really needed? Maybe for later parsing
    var tokens = List(Token).init(allocator);
    defer tokens.deinit();

    while (scanner.scanToken()) |token| {
        try tokens.append(token);
        try stdout.print("{}\n", .{token});
    }
}

fn keywords(allocator: *mem.Allocator) !KeywordMap {
    var map = KeywordMap.init(allocator);
    errdefer map.deinit();

    try map.put("and", TokenType.AND);
    try map.put("class", TokenType.CLASS);
    try map.put("else", TokenType.ELSE);
    try map.put("false", TokenType.FALSE);
    try map.put("for", TokenType.FOR);
    try map.put("fun", TokenType.FUN);
    try map.put("if", TokenType.IF);
    try map.put("nil", TokenType.NIL);
    try map.put("or", TokenType.OR);
    try map.put("print", TokenType.PRINT);
    try map.put("return", TokenType.RETURN);
    try map.put("super", TokenType.SUPER);
    try map.put("this", TokenType.THIS);
    try map.put("true", TokenType.TRUE);
    try map.put("var", TokenType.VAR);
    try map.put("while", TokenType.WHILE);

    return map;
}

//=== Reporting ===//

pub fn reportError(line: usize, comptime format: []const u8, args: anytype) void {
    had_error = true;
    report(line, "", format, args);
}

pub fn report(line: usize, where: []u8, comptime format: []const u8, args: anytype) void {
    var out = std.io.getStdErr().writer();

    // TODO (Matteo): Better error handling?
    // Maybe but at the moment I don't want to bother if writing to stderr fails.
    // We are a CLI interpreter after all.

    out.print("[line {}] Error{s}: ", .{ line, where }) catch unreachable;
    out.print(format, args) catch unreachable;
    out.print("\n", .{}) catch unreachable;
}

//=== EOF ===//
