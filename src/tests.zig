const std = @import("std");
const fs = std.fs;

const lox = @import("lox.zig");

//======//

test "test read unbuffered" {
    var f = try fs.openFileAbsolute("C:/temp/0311158R.txt", .{ .read = true });
    defer f.close();

    var reader = f.reader();
    var timer = try std.time.Timer.start();
    var temp: [1024]u8 = undefined;

    var bytes = try reader.readAll(temp[0..]);
    try std.testing.expect(bytes == temp.len);

    std.log.warn("Unbuffered read {} bytes in {}ns\n", .{ bytes, timer.lap() });
}

test "test read buffered" {
    var f = try fs.openFileAbsolute("C:/temp/0311158R.txt", .{ .read = true });
    defer f.close();

    var reader = buffered(4096, f.reader()).reader();
    var timer = try std.time.Timer.start();
    var temp: [1024]u8 = undefined;

    var bytes = try reader.readAll(temp[0..]);
    try std.testing.expect(bytes == temp.len);

    std.log.warn("Buffered read {} bytes in {}ns\n", .{ bytes, timer.lap() });
}

/// Create a buffered reader with custom size
fn buffered(
    comptime size: usize,
    underlying_stream: anytype,
) std.io.BufferedReader(size, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_reader = underlying_stream };
}

//======//

const StringMap = std.StringHashMap(usize);

test "test const string hash map" {
    std.log.warn("...", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = &gpa.allocator;
    var map = try createMap(alloc);
    defer map.deinit();

    var iter = map.iterator();
    while (iter.next()) |entry| {
        std.log.warn("{s}: {}", .{ entry.key_ptr.*, entry.value_ptr.* });
        try std.testing.expect(entry.key_ptr.len == entry.value_ptr.*);
    }

    try std.testing.expect(map.get("Hello").? == 5);
}

fn createMap(allocator: *std.mem.Allocator) !StringMap {
    var map = StringMap.init(allocator);
    errdefer map.deinit();

    try map.put("Hello", "Hello".len);

    return map;
}

//======//

test "test visitor pattern" {
    const Beignet = struct {};
    const Cruller = struct {};

    const Pastry = union(enum) {
        const Self = @This();

        beignet: Beignet,
        cruller: Cruller,

        fn accept(self: *Self, visitor: anytype) void {
            switch (self.*) {
                .beignet => |value| visitor.visitBeignet(value),
                .cruller => |value| visitor.visitCruller(value),
            }
        }
    };

    const Cook = struct {
        const Self = @This();

        fn visitBeignet(_: *Self, _: Beignet) void {
            std.log.warn("Cooking beignet", .{});
        }

        fn visitCruller(_: *Self, _: Cruller) void {
            std.log.warn("Cooking cruller", .{});
        }
    };

    var b = Pastry{ .beignet = Beignet{} };
    var c = Cook{};

    b.accept(&c);
}

//======//

const ast = lox.ast;
const Token = lox.Token;
const TokenType = lox.TokenType;
const Expr = ast.Expr;

test "test ast" {
    const allocator = std.testing.allocator;
    const minus: []const u8 = "-";

    var expr = try Expr.createLiteral(allocator, lox.Literal{ .number = 123 });
    expr = try Expr.createGrouping(allocator, expr);
    expr = try Expr.createUnary(allocator, Token{
        .type = TokenType.MINUS,
        .lexeme = minus,
        .literal = lox.Literal.none,
        .line = 1,
    }, expr);
    defer expr.destroyTree(allocator);

    var printer = ast.AstPrinter.init();
    try printer.printExpr(expr);
}

//======//
