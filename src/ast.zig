const std = @import("std");
const mem = std.mem;
const io = std.io;
const fs = std.fs;

const lox = @import("lox.zig");

const Token = lox.Token;
const TokenType = lox.TokenType;
const Literal = lox.Literal;

/// Handle to an expression in the Ast
pub const ExprId = usize;

// NOTE (Matteo): Internal representation of an expression
const Expr = union(enum) {
    literal: Literal,
    grouping: ExprId,
    unary: Unary,
    binary: Binary,

    const Unary = struct {
        operator: Token,
        right: ExprId,
    };

    const Binary = struct {
        left: ExprId,
        operator: Token,
        right: ExprId,
    };
};

/// Mantains an abstract syntax tree
pub const Ast = struct {
    nodes: std.ArrayList(Expr),

    const Self = @This();

    pub fn init(allocator: *mem.Allocator) Self {
        var self = Self{
            .nodes = std.ArrayList(Expr).init(allocator),
        };

        // NOTE (Matteo): Element 0 is dummy
        _ = self.nodes.addOne() catch unreachable;

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.nodes.deinit();
    }

    pub fn createLiteral(self: *Self, value: Literal) ExprId {
        self.nodes.append(.{ .literal = value }) catch return 0;

        return self.lastId();
    }

    pub fn createGrouping(self: *Self, expr: ExprId) ExprId {
        self.nodes.append(.{ .grouping = expr }) catch return 0;

        return self.lastId();
    }

    pub fn createUnary(self: *Self, operator: Token, right: ExprId) ExprId {
        self.nodes.append(.{
            .unary = .{ .operator = operator, .right = right },
        }) catch return 0;

        return self.lastId();
    }

    pub fn createBinary(
        self: *Self,
        left: ExprId,
        operator: Token,
        right: ExprId,
    ) ExprId {
        self.nodes.append(.{
            .binary = .{ .left = left, .operator = operator, .right = right },
        }) catch return 0;

        return self.lastId();
    }

    pub fn printTree(self: *const Self, root: ExprId, writer: anytype) anyerror!void {
        switch (self.nodes.items[root]) {
            .literal => |lit| {
                switch (lit) {
                    .string => |value| try writer.print("{s}", .{value}),
                    .number => |value| try writer.print("{}", .{value}),
                    .none => try writer.print("nil", .{}),
                }
            },
            .grouping => |group| {
                try writer.print("(group ", .{});
                try self.printTree(group, writer);
                try writer.print(")", .{});
            },
            .unary => |value| {
                try writer.print("({s} ", .{value.operator.lexeme});
                try self.printTree(value.right, writer);
                try writer.print(")", .{});
            },
            .binary => |value| {
                try writer.print("({s} ", .{value.operator.lexeme});
                try self.printTree(value.left, writer);
                try writer.print(" ", .{});
                try self.printTree(value.right, writer);
                try writer.print(")", .{});
            },
        }
    }

    fn lastId(self: *const Self) ExprId {
        return self.nodes.items.len - 1;
    }
};
