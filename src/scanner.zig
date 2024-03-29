const std = @import("std");

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;
const Literal = token.Literal;

const Interpreter = @import("Interpreter.zig");

pub const Scanner = struct {
    const Self = @This();

    ctx: *Interpreter,
    source: []u8,
    current: usize = 0,
    line: usize = 1,

    pub fn init(ctx: *Interpreter, source: []u8) Self {
        return Self{
            .source = source,
            .ctx = ctx,
        };
    }

    pub fn scanToken(self: *Self) ?Token {
        if (self.isAtEnd()) return null;

        while (!self.isAtEnd()) {
            // We are at the beginning of the next lexeme.
            self.source = self.source[self.current..];
            self.current = 0;

            var c = self.peek();

            self.advance();

            switch (c) {
                // Punctuation
                '(' => return self.makeToken(.LEFT_PAREN),
                ')' => return self.makeToken(.RIGHT_PAREN),
                '{' => return self.makeToken(.LEFT_BRACE),
                '}' => return self.makeToken(.RIGHT_BRACE),
                ',' => return self.makeToken(.COMMA),
                '.' => return self.makeToken(.DOT),
                '-' => return self.makeToken(.MINUS),
                '+' => return self.makeToken(.PLUS),
                ';' => return self.makeToken(.SEMICOLON),
                '*' => return self.makeToken(.STAR),
                // *_EQUAL operators
                '!' => return self.makeToken(if (self.match('=')) .BANG_EQUAL else .BANG),
                '=' => return self.makeToken(if (self.match('=')) .EQUAL_EQUAL else .EQUAL),
                '<' => return self.makeToken(if (self.match('=')) .LESS_EQUAL else .LESS),
                '>' => return self.makeToken(if (self.match('=')) .GREATER_EQUAL else .GREATER),
                '/' => {
                    if (self.match('/')) {
                        // Discard comment characters until the line end
                        while (!self.isAtEnd() and self.peek() != '\n') self.advance();
                    } else {
                        return self.makeToken(.SLASH);
                    }
                },
                // Whitespace
                ' ', '\r', '\t' => {},
                '\n' => self.line += 1,
                // Strings
                '"' => if (self.makeString()) |s| {
                    return s;
                } else |err| switch (err) {
                    error.UnterminatedString => {
                        self.ctx.reportError(self.line, "Unterminated string.", .{});
                    },
                    else => unreachable,
                },
                // Other: numbers, identifiers, invalid tokens
                else => {
                    if (isDigit(c)) {
                        return self.makeNumber();
                    } else if (isAlpha(c)) {
                        return self.makeIdentifier();
                    } else {
                        self.ctx.reportError(self.line, "Invalid token: {}", .{c});
                    }
                },
            }
        }

        // TODO (Matteo): is this really useful?
        return Token{
            .type = .EOF,
            .literal = Literal.none,
            .lexeme = "",
            .line = self.line,
        };
    }

    fn isAtEnd(self: *const Self) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Self) void {
        self.current += 1;
    }

    fn match(self: *Self, expected: u8) bool {
        if (self.peek() == expected) {
            self.advance();
            return true;
        }
        return false;
    }

    fn peek(self: *const Self) u8 {
        return if (self.isAtEnd()) 0 else self.source[self.current];
    }

    fn peekNext(self: *const Self) u8 {
        var next = self.current + 1;
        return if (next >= self.source.len) 0 else self.source[next];
    }

    fn makeToken(self: *const Self, tok_type: TokenType) Token {
        return self.makeLiteral(tok_type, Literal.none);
    }

    fn makeLiteral(self: *const Self, tok_type: TokenType, value: Literal) Token {
        return Token{
            .type = tok_type,
            .literal = value,
            .lexeme = self.source[0..self.current],
            .line = self.line,
        };
    }

    fn makeString(self: *Self) !Token {
        while (!self.isAtEnd() and self.peek() != '"') {
            if (self.peek() == '\n') self.line += 1;
            self.advance();
        }

        if (self.isAtEnd()) {
            return error.UnterminatedString;
        }

        // The closing ".
        self.advance();

        // Trim the surrounding quotes.
        var value = self.source[1 .. self.current - 1];
        return self.makeLiteral(.STRING, Literal{ .string = value });
    }

    fn makeNumber(self: *Self) Token {
        while (isDigit(self.peek())) self.advance();

        // Look for a fractional part.
        if (self.peek() == '.' and isDigit(self.peekNext())) {
            // Consume the "."
            self.advance();

            while (isDigit(self.peek())) self.advance();
        }

        var lexeme = self.source[0..self.current];
        var value = std.fmt.parseFloat(f64, lexeme) catch unreachable;

        return Token{
            .type = .NUMBER,
            .literal = .{ .number = value },
            .lexeme = lexeme,
            .line = self.line,
        };
    }

    fn makeIdentifier(self: *Self) Token {
        while (isAlphaNumeric(self.peek())) self.advance();

        const value = self.source[0..self.current];
        const key = self.ctx.keywords.get(value) orelse .IDENTIFIER;

        return Token{
            .type = key,
            .literal = .{ .string = value },
            .lexeme = value,
            .line = self.line,
        };
    }
};

//=== Utilities ===//

fn isDigit(c: u8) bool {
    return (c >= '0' and c <= '9');
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isAlphaNumeric(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}
