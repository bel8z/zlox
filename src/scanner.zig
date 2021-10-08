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

    pub fn init(bytes: []u8) Self {
        return Self{
            .source = bytes,
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
                '(' => return self.addToken(TokenType.LEFT_PAREN),
                ')' => return self.addToken(TokenType.RIGHT_PAREN),
                '{' => return self.addToken(TokenType.LEFT_BRACE),
                '}' => return self.addToken(TokenType.RIGHT_BRACE),
                ',' => return self.addToken(TokenType.COMMA),
                '.' => return self.addToken(TokenType.DOT),
                '-' => return self.addToken(TokenType.MINUS),
                '+' => return self.addToken(TokenType.PLUS),
                ';' => return self.addToken(TokenType.SEMICOLON),
                '*' => return self.addToken(TokenType.STAR),
                // *_EQUAL operators
                '!' => return self.addToken(if (self.match('=')) TokenType.BANG_EQUAL else TokenType.BANG),
                '=' => return self.addToken(if (self.match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL),
                '<' => return self.addToken(if (self.match('=')) TokenType.LESS_EQUAL else TokenType.LESS),
                '>' => return self.addToken(if (self.match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER),
                '/' => {
                    if (self.match('/')) {
                        while (self.peek() != '\n' and !self.isAtEnd()) {
                            // Discard comment characters until the line end
                            _ = self.advance();
                        }
                    } else {
                        return self.addToken(TokenType.SLASH);
                    }
                },
                // Whitespace
                ' ', '\r', 't' => {},
                '\n' => self.line += 1,
                // Identifiers
                // Strings
                '"' => if (self.string()) |s| {
                    return s;
                } else |err| switch (err) {
                    error.UnterminatedString => {
                        // TODO (Matteo): Better error handling
                        lox.reportError(self.line, "Unterminated string.", .{}) catch unreachable;
                    },
                    else => unreachable,
                },
                //
                else => {
                    if (isDigit(c)) {
                        return self.number();
                    } else if (isAlpha(c)) {
                        return self.identifier();
                    } else {
                        // TODO (Matteo): better error handling
                        lox.reportError(self.line, "Invalid token: {}", .{c}) catch unreachable;
                    }
                },
            }
        }

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

    fn string(self: *Self) !Token {
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
        return self.addTokenLiteral(TokenType.STRING, Literal{ .string = value });
    }

    fn number(self: *Self) Token {
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
            .type = TokenType.NUMBER,
            .literal = Literal{ .number = value },
            .lexeme = lexeme,
            .line = self.line,
        };
    }

    fn identifier(self: *Self) Token {
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }

        var value = self.source[self.start..self.current];

        return Token{
            .type = TokenType.IDENTIFIER,
            .literal = Literal{ .identifier = value },
            .lexeme = value,
            .line = self.line,
        };
    }

    fn addToken(self: *Self, tok_type: TokenType) Token {
        return self.addTokenLiteral(tok_type, Literal.none);
    }

    fn addTokenLiteral(self: *Self, tok_type: TokenType, literal: Literal) Token {
        return Token{
            .type = tok_type,
            .literal = literal,
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
