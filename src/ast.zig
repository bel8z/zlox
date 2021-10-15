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

    pub fn accept(self: *Expr, comptime T: type, visitor: anytype) !T {
        switch (self) {
            .literal => |value| return visitor.visitLiteral(value),
            .grouping => |value| return visitor.visitGrouping(value),
            .binary => |value| return visitor.visitBinary(value),
            .unary => |value| return visitor.visitUnary(value),
        }
    }
};

pub fn AstPrinter(comptime T: type) type {
    return struct {
        const Self = @This();

        writer: *T,

        pub fn init(writer: *T) Self {
            return Self{ .writer = writer };
        }

        pub fn printExpr(self: *Self, expr: *const Expr) !void {
            try expr.accept(void, self);
        }

        fn visitLiteral(self: *Self, literal: Literal) !void {
            switch (literal) {
                .string => |value| try self.print("{s}", .{value}),
                .number => |value| try self.print("{}", .{value}),
                .none => try self.print("nil", .{}),
            }
        }

        fn visitGrouping(self: *Self, expr: Expr) void {
            try self.print("(");
            try expr.accept(self);
            try self.print(")");
        }

        fn visitUnary(self: *Self, unary: Expr.Unary) void {
            try self.print("({s} ", .{unary.operator.lexeme});
            try unary.right.accept(self);
            try self.print(")", .{});
        }

        fn visitBinary(self: *Self, unary: Expr.Binary) void {
            try self.print("({s} ", .{unary.operator.lexeme});
            try unary.left.accept(self);
            try self.print(" ", .{});
            try unary.right.accept(self);
            try self.print(")", .{});
        }

        fn print(self: Self, comptime format: []const u8, args: anytype) !void {
            try self.print(format, args);
        }
    };
}
