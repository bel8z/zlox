// Standard imports
const std = @import("std");
const mem = std.mem;
const io = std.io;
const List = std.ArrayList;

// Constants
const max_size = 1024 * 1024 * 1024;

//=== Main interpreter loops ===//

// TODO (Matteo): Improve this
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

fn run(allocator: *mem.Allocator, bytes: []u8) !void {
    var scanner = Scanner.init(allocator, bytes);
    defer scanner.deinit();

    var tokens = try scanner.scanTokens();
    var stdout = io.getStdOut().writer();

    for (tokens.items) |token| {
        try stdout.print("{}\n", .{token});
    }
}

//=== Reporting ===//

pub fn reportError(line: usize, comptime format: []const u8, args: anytype) !void {
    had_error = true;
    try report(line, "", format, args);
}

pub fn report(line: usize, where: []u8, comptime format: []const u8, args: anytype) !void {
    var out = std.io.getStdErr().writer();

    try out.print("[line {}] Error{s}: ", .{ line, where });
    try out.print(format, args);
    try out.print("\n", .{});
}

//=== Scanning ===//

const Literal = union(enum) {
    identifier: []u8,
    number: f64,
    string: []u8,
    none,
};

const TokenType = enum {
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

const Token = struct {
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
            Literal.string => |value| try std.fmt.format(writer, "{} {s}", .{ self.type, value }),
            Literal.identifier => |value| try std.fmt.format(writer, "{} {s}", .{ self.type, value }),
            Literal.number => |value| try std.fmt.format(writer, "{} {}", .{ self.type, value }),
            Literal.none => try std.fmt.format(writer, "{} {s}", .{ self.type, self.lexeme }),
        }
    }
};

const Scanner = struct {
    const Self = @This();

    source: []u8,

    tokens: List(Token),

    start: usize = 0,
    current: usize = 0,
    line: usize = 1,

    fn init(allocator: *mem.Allocator, bytes: []u8) Self {
        return Self{
            .source = bytes,
            .tokens = List(Token).init(allocator),
        };
    }

    fn deinit(self: *Self) void {
        self.tokens.deinit();
    }

    fn scanTokens(self: *Self) !List(Token) {
        while (!self.isAtEnd()) {
            // We are at the beginning of the next lexeme.
            self.start = self.current;
            try self.scanToken();
        }

        try self.tokens.append(Token{
            .type = .EOF,
            .literal = Literal.none,
            .lexeme = "",
            .line = self.line,
        });

        return self.tokens;
    }

    fn scanToken(self: *Self) !void {
        var c = self.advance();
        switch (c) {
            // Punctuation
            '(' => try self.addToken(TokenType.LEFT_PAREN),
            ')' => try self.addToken(TokenType.RIGHT_PAREN),
            '{' => try self.addToken(TokenType.LEFT_BRACE),
            '}' => try self.addToken(TokenType.RIGHT_BRACE),
            ',' => try self.addToken(TokenType.COMMA),
            '.' => try self.addToken(TokenType.DOT),
            '-' => try self.addToken(TokenType.MINUS),
            '+' => try self.addToken(TokenType.PLUS),
            ';' => try self.addToken(TokenType.SEMICOLON),
            '*' => try self.addToken(TokenType.STAR),
            // *_EQUAL operators
            '!' => try self.addToken(if (self.match('=')) TokenType.BANG_EQUAL else TokenType.BANG),
            '=' => try self.addToken(if (self.match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL),
            '<' => try self.addToken(if (self.match('=')) TokenType.LESS_EQUAL else TokenType.LESS),
            '>' => try self.addToken(if (self.match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER),
            '/' => {
                if (self.match('/')) {
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        // Discard comment characters until the line end
                        _ = self.advance();
                    }
                } else {
                    try self.addToken(TokenType.SLASH);
                }
            },
            // Whitespace
            ' ', '\r', 't' => {},
            '\n' => self.line += 1,
            // Identifiers
            // Strings
            '"' => try self.string(),
            //
            else => {
                if (isDigit(c)) {
                    try self.number();
                } else if (isAlpha(c)) {
                    try self.identifier();
                } else {
                    try reportError(self.line, "Invalid token: {}", .{c});
                }
            },
        }
    }

    fn isAtEnd(self: *const Self) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Self) u8 {
        var c = self.source[self.current];
        self.current += 1;
        return c;
    }

    fn match(self: *Self, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;
        self.current += 1;
        return true;
    }

    fn peek(self: *Self) u8 {
        return if (self.isAtEnd()) 0 else self.source[self.current];
    }

    fn peekNext(self: *Self) u8 {
        var next = self.current + 1;
        return if (next >= self.source.len) 0 else self.source[next];
    }

    fn string(self: *Self) !void {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') {
                self.line += 1;
            }
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            try reportError(self.line, "Unterminated string.", .{});
            return;
        }

        // The closing ".
        _ = self.advance();

        // Trim the surrounding quotes.
        var value = self.source[self.start + 1 .. self.current - 1];
        try self.addTokenLiteral(TokenType.STRING, Literal{ .string = value });
    }

    fn number(self: *Self) !void {
        while (isDigit(self.peek())) {
            _ = self.advance();
        }

        // Look for a fractional part.
        if (self.peek() == '.' and isDigit(self.peekNext())) {
            // Consume the "."
            _ = self.advance();

            while (isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        var lexeme = self.source[self.start..self.current];
        var value = std.fmt.parseFloat(f64, lexeme) catch unreachable;

        try self.tokens.append(Token{
            .type = TokenType.NUMBER,
            .literal = Literal{ .number = value },
            .lexeme = lexeme,
            .line = self.line,
        });
    }

    fn identifier(self: *Self) !void {
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }

        var value = self.source[self.start..self.current];

        try self.tokens.append(Token{
            .type = TokenType.IDENTIFIER,
            .literal = Literal{ .identifier = value },
            .lexeme = value,
            .line = self.line,
        });
    }

    fn addToken(self: *Self, tok_type: TokenType) !void {
        try self.addTokenLiteral(tok_type, Literal.none);
    }

    fn addTokenLiteral(self: *Self, tok_type: TokenType, literal: Literal) !void {
        try self.tokens.append(Token{
            .type = tok_type,
            .literal = literal,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
        });
    }
};

fn isDigit(c: u8) bool {
    return (c >= '0' and c <= '9');
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isAlphaNumeric(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}

//=== EOF ===//
