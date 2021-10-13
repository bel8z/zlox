const std = @import("std");
const lox = @import("lox.zig");

const Token = lox.Token;
const TokenType = lox.TokenType;
const Literal = lox.Literal;

pub const Scanner = struct {
    const Self = @This();

    source: []u8,
    start: usize = 0,
    current: usize = 0,
    line: usize = 1,
    ctx: *lox.Lox,

    pub fn init(bytes: []u8, ctx: *lox.Lox) Self {
        return Self{
            .source = bytes,
            .ctx = ctx,
        };
    }

    pub fn scanToken(self: *Self) ?Token {
        if (self.isAtEnd()) return null;

        while (!self.isAtEnd()) {
            // We are at the beginning of the next lexeme.
            self.start = self.current;

            var c = self.advance();

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
                        while (self.peek() != '\n' and !self.isAtEnd()) {
                            // Discard comment characters until the line end
                            _ = self.advance();
                        }
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

    fn makeToken(self: *Self, tok_type: TokenType) Token {
        return self.makeLiteral(tok_type, Literal.none);
    }

    fn makeString(self: *Self) !Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') {
                self.line += 1;
            }
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            return error.UnterminatedString;
        }

        // The closing ".
        _ = self.advance();

        // Trim the surrounding quotes.
        var value = self.source[self.start + 1 .. self.current - 1];
        return self.makeLiteral(.STRING, Literal{ .string = value });
    }

    fn makeNumber(self: *Self) Token {
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

        return Token{
            .type = .NUMBER,
            .literal = .{ .number = value },
            .lexeme = lexeme,
            .line = self.line,
        };
    }

    fn makeIdentifier(self: *Self) Token {
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }

        const value: []u8 = self.source[self.start..self.current];
        const key = self.ctx.keywords.get(value) orelse .IDENTIFIER;

        return Token{
            .type = key,
            .literal = .{ .string = value },
            .lexeme = value,
            .line = self.line,
        };
    }

    fn makeLiteral(self: *Self, tok_type: TokenType, value: Literal) Token {
        return Token{
            .type = tok_type,
            .literal = value,
            .lexeme = self.source[self.start..self.current],
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
