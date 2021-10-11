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
                '(' => return self.token(TokenType.LEFT_PAREN),
                ')' => return self.token(TokenType.RIGHT_PAREN),
                '{' => return self.token(TokenType.LEFT_BRACE),
                '}' => return self.token(TokenType.RIGHT_BRACE),
                ',' => return self.token(TokenType.COMMA),
                '.' => return self.token(TokenType.DOT),
                '-' => return self.token(TokenType.MINUS),
                '+' => return self.token(TokenType.PLUS),
                ';' => return self.token(TokenType.SEMICOLON),
                '*' => return self.token(TokenType.STAR),
                // *_EQUAL operators
                '!' => return self.token(if (self.match('=')) TokenType.BANG_EQUAL else TokenType.BANG),
                '=' => return self.token(if (self.match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL),
                '<' => return self.token(if (self.match('=')) TokenType.LESS_EQUAL else TokenType.LESS),
                '>' => return self.token(if (self.match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER),
                '/' => {
                    if (self.match('/')) {
                        while (self.peek() != '\n' and !self.isAtEnd()) {
                            // Discard comment characters until the line end
                            _ = self.advance();
                        }
                    } else {
                        return self.token(TokenType.SLASH);
                    }
                },
                // Whitespace
                ' ', '\r', '\t' => {},
                '\n' => self.line += 1,
                // Identifiers
                // Strings
                '"' => if (self.string()) |s| {
                    return s;
                } else |err| switch (err) {
                    error.UnterminatedString => {
                        lox.reportError(self.line, "Unterminated string.", .{});
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
                        lox.reportError(self.line, "Invalid token: {}", .{c});
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
        return self.literal(TokenType.STRING, Literal{ .string = value });
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

        const value: []u8 = self.source[self.start..self.current];
        const key = keyword(value) orelse TokenType.IDENTIFIER;

        return Token{
            .type = key,
            .literal = Literal{ .identifier = value },
            .lexeme = value,
            .line = self.line,
        };
    }

    fn token(self: *Self, tok_type: TokenType) Token {
        return self.literal(tok_type, Literal.none);
    }

    fn literal(self: *Self, tok_type: TokenType, value: Literal) Token {
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

fn keyword(value: []const u8) ?TokenType {
    // TODO (Matteo): Use a hash map
    if (std.mem.eql(u8, "and", value)) return TokenType.AND;
    if (std.mem.eql(u8, "class", value)) return TokenType.CLASS;
    if (std.mem.eql(u8, "else", value)) return TokenType.ELSE;
    if (std.mem.eql(u8, "false", value)) return TokenType.FALSE;
    if (std.mem.eql(u8, "for", value)) return TokenType.FOR;
    if (std.mem.eql(u8, "fun", value)) return TokenType.FUN;
    if (std.mem.eql(u8, "if", value)) return TokenType.IF;
    if (std.mem.eql(u8, "nil", value)) return TokenType.NIL;
    if (std.mem.eql(u8, "or", value)) return TokenType.OR;
    if (std.mem.eql(u8, "print", value)) return TokenType.PRINT;
    if (std.mem.eql(u8, "return", value)) return TokenType.RETURN;
    if (std.mem.eql(u8, "super", value)) return TokenType.SUPER;
    if (std.mem.eql(u8, "this", value)) return TokenType.THIS;
    if (std.mem.eql(u8, "true", value)) return TokenType.TRUE;
    if (std.mem.eql(u8, "var", value)) return TokenType.VAR;
    if (std.mem.eql(u8, "while", value)) return TokenType.WHILE;

    return null;
}
