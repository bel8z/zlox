const std = @import("std");
const lox = @import("lox.zig");

const Token = lox.Token;
const TokenType = lox.TokenType;
const Literal = lox.Literal;

pub const Expr = union(enum) {
    literal: Literal,
    grouping: Expr,
    binary: Binary,
    unary: Unary,

    pub const Unary = struct {
        operator: Token,
        right: Expr,
    };

    pub const Binary = struct {
        left: Expr,
        operator: Token,
        right: Expr,
    };

    pub fn accept(self: *Expr, comptime T: type, visitor: anytype) T {
        switch (self) {
            .literal => |value| return visitor.visitLiteral(value),
            .grouping => |value| return visitor.visitGrouping(value),
            .binary => |value| return visitor.visitBinary(value),
            .unary => |value| return visitor.visitUnary(value),
        }
    }
};

pub const AstPrinter = struct {
    const Self = @This();

    pub fn print(expr: *const Expr, writer: anytype) void {}
};
