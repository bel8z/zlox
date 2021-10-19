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

    pub fn walk(
        self: *const Self,
        root: ExprId,
        comptime T: type,
        visitor: anytype,
    ) anyerror!T {
        switch (self.nodes.items[root]) {
            .literal => |value| return visitor.visitLiteral(value),
            .grouping => |value| return visitor.visitGrouping(value),
            .unary => |value| return visitor.visitUnary(value),
            .binary => |value| return visitor.visitBinary(value),
        }
    }

    fn lastId(self: *const Self) ExprId {
        return self.nodes.items.len - 1;
    }
};

pub const AstPrinter = struct {
    const Self = @This();

    writer: fs.File.Writer,
    tree: *const Ast = undefined,

    pub fn init() Self {
        return Self{ .writer = io.getStdErr().writer() };
    }

    pub fn printTree(self: *Self, tree: *const Ast, root: ExprId) !void {
        self.tree = tree;
        try tree.walk(root, void, self);
    }

    fn visitLiteral(self: *Self, literal: Literal) void {
        switch (literal) {
            .string => |value| self.print("{s}", .{value}),
            .number => |value| self.print("{}", .{value}),
            .none => self.print("nil", .{}),
        }
    }

    fn visitGrouping(self: *Self, expr: ExprId) !void {
        self.print("(group ", .{});
        try self.tree.walk(expr, void, self);
        self.print(")", .{});
    }

    fn visitUnary(self: *Self, unary: Expr.Unary) !void {
        self.print("({s} ", .{unary.operator.lexeme});
        try self.tree.walk(unary.right, void, self);
        self.print(")", .{});
    }

    fn visitBinary(self: *Self, binary: Expr.Binary) !void {
        self.print("({s} ", .{binary.operator.lexeme});
        try self.tree.walk(binary.left, void, self);
        self.print(" ", .{});
        try self.tree.walk(binary.right, void, self);
        self.print(")", .{});
    }

    fn print(self: *Self, comptime format: []const u8, args: anytype) void {
        self.writer.print(format, args) catch unreachable;
    }
};
