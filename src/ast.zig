const std = @import("std");
const mem = std.mem;
const io = std.io;
const fs = std.fs;

const lox = @import("lox.zig");

const Token = lox.Token;
const TokenType = lox.TokenType;
const Literal = lox.Literal;

pub const Expr = union(enum) {
    literal: Literal,
    grouping: *Expr,
    unary: Unary,
    binary: Binary,

    pub const Unary = struct {
        operator: Token,
        right: *Expr,
    };

    pub const Binary = struct {
        left: *Expr,
        operator: Token,
        right: *Expr,
    };

    pub fn createLiteral(allocator: *mem.Allocator, value: Literal) !*Expr {
        var self: *Expr = try allocator.create(Expr);
        self.* = .{ .literal = value };
        return self;
    }

    pub fn createGrouping(allocator: *mem.Allocator, expr: *Expr) !*Expr {
        var self: *Expr = try allocator.create(Expr);
        self.* = .{ .grouping = expr };
        return self;
    }

    pub fn createUnary(allocator: *mem.Allocator, operator: Token, right: *Expr) !*Expr {
        var self: *Expr = try allocator.create(Expr);
        self.* = .{ .unary = .{ .operator = operator, .right = right } };
        return self;
    }

    pub fn createBinary(
        allocator: *mem.Allocator,
        left: *Expr,
        operator: Token,
        right: *Expr,
    ) !*Expr {
        var self: *Expr = try allocator.create(Expr);
        self.* = .{ .binary = .{ .left = left, .operator = operator, .right = right } };
        return self;
    }

    pub fn destroyTree(root: *Expr, allocator: *mem.Allocator) void {
        switch (root.*) {
            .literal => {},
            .grouping => |value| value.destroyTree(allocator),
            .unary => |value| value.right.destroyTree(allocator),
            .binary => |value| {
                value.left.destroyTree(allocator);
                value.right.destroyTree(allocator);
            },
        }
        allocator.destroy(root);
    }

    pub fn accept(self: *const Expr, comptime T: type, visitor: anytype) anyerror!T {
        switch (self.*) {
            .literal => |value| return visitor.visitLiteral(value),
            .grouping => |value| return visitor.visitGrouping(value),
            .unary => |value| return visitor.visitUnary(value),
            .binary => |value| return visitor.visitBinary(value),
        }
    }
};

pub const AstPrinter = struct {
    const Self = @This();

    writer: fs.File.Writer,

    pub fn init() Self {
        return Self{ .writer = io.getStdErr().writer() };
    }

    pub fn printExpr(self: *const Self, expr: *const Expr) !void {
        try expr.accept(void, self);
    }

    fn visitLiteral(self: *const Self, literal: Literal) void {
        switch (literal) {
            .string => |value| self.print("{s}", .{value}),
            .number => |value| self.print("{}", .{value}),
            .none => self.print("nil", .{}),
        }
    }

    fn visitGrouping(self: *const Self, expr: *const Expr) !void {
        self.print("(group ", .{});
        try expr.accept(void, self);
        self.print(")", .{});
    }

    fn visitUnary(self: *const Self, unary: Expr.Unary) !void {
        self.print("({s} ", .{unary.operator.lexeme});
        try unary.right.accept(void, self);
        self.print(")", .{});
    }

    fn visitBinary(self: *const Self, unary: Expr.Binary) !void {
        self.print("({s} ", .{unary.operator.lexeme});
        try unary.left.accept(void, self);
        self.print(" ", .{});
        try unary.right.accept(void, self);
        self.print(")", .{});
    }

    fn print(self: *const Self, comptime format: []const u8, args: anytype) void {
        self.writer.print(format, args) catch unreachable;
    }
};
