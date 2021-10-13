// Standard imports
const std = @import("std");

pub const Literal = union(enum) {
    number: f64,
    string: []u8,
    none,
};

pub const TokenType = enum {
    // Single-character tokens.
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,

    // One or two character tokens.
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,

    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,

    // Keywords.
    AND,
    CLASS,
    ELSE,
    FALSE,
    FUN,
    FOR,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,
    EOF,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []u8,
    literal: Literal,
    line: usize,

    pub fn format(
        self: *const Token,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self.literal) {
            .string => |value| try std.fmt.format(writer, "{} {s}", .{ self.type, value }),
            .number => |value| try std.fmt.format(writer, "{} {}", .{ self.type, value }),
            .none => try std.fmt.format(writer, "{} {s}", .{ self.type, self.lexeme }),
        }
    }
};
