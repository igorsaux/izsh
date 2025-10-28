const std = @import("std");

pub const TokenTag = enum(u8) {
    string,
    /// '
    squote,
    /// "
    dquote,
};

pub const Quote = enum(u8) {
    no,
    dquote,
    squote,
};

pub const TokenValue = union(TokenTag) {
    string: struct {
        data: []const u8,
        quotes: Quote,
    },
    squote: struct {},
    dquote: struct {},
};

pub const Token = struct {
    pos: usize,
    value: TokenValue,
};

const Error = error{ InvalidToken, OutOfMemory };

pub const ErrorInfo = struct {
    pos: usize = 0,
};

const StringState = struct {
    start: usize,
};

tokens: std.ArrayList(Token),
quoting: Quote = .no,
string: ?StringState = null,

const Lexer = @This();

fn newQuoteState(current: Quote, new: Quote) Quote {
    if (current == .no) {
        return new;
    }

    if (current == new) {
        return .no;
    }

    return current;
}

fn onQuote(this: *Lexer, allocator: std.mem.Allocator, quote: Quote, input: []const u8, pos: usize) error{OutOfMemory}!void {
    const new_quote: Quote = newQuoteState(this.quoting, quote);

    if (new_quote == this.quoting) {
        if (this.string == null) {
            this.string = .{ .start = pos };
        }

        return;
    }

    try this.tryAppendString(allocator, input, pos);
    this.quoting = new_quote;

    var value: TokenValue = undefined;

    switch (quote) {
        .no => return,
        .dquote => {
            value = .{ .dquote = .{} };
        },
        .squote => {
            value = .{ .squote = .{} };
        },
    }

    try this.tokens.append(allocator, .{
        .pos = pos,
        .value = value,
    });
}

fn tryAppendString(this: *Lexer, allocator: std.mem.Allocator, input: []const u8, pos: usize) error{OutOfMemory}!void {
    if (this.string == null) {
        return;
    }

    try this.tokens.append(allocator, .{
        .pos = this.string.?.start,
        .value = .{
            .string = .{
                .data = input[this.string.?.start..pos],
                .quotes = this.quoting,
            },
        },
    });
    this.string = null;
}

pub fn parse(allocator: std.mem.Allocator, input: []const u8, err_out: ?*ErrorInfo) Error!Lexer {
    var this: Lexer = .{
        .tokens = try .initCapacity(allocator, 128),
    };

    errdefer this.deinit(allocator);

    var reader: std.Io.Reader = .fixed(input);

    while (reader.seek < reader.end) {
        const chr = reader.peekByte() catch unreachable;
        const pos = reader.seek;

        if (std.ascii.isWhitespace(chr)) {
            if (this.quoting == .no) {
                try this.tryAppendString(allocator, input, pos);
            }

            _ = reader.takeByte() catch undefined;

            continue;
        }

        if (chr == '\x00') {
            if (err_out) |err| {
                err.*.pos = reader.seek;
            }

            return Error.InvalidToken;
        }

        switch (chr) {
            '\'' => {
                try this.onQuote(allocator, .squote, input, pos);
                _ = reader.takeByte() catch unreachable;

                continue;
            },
            '"' => {
                try this.onQuote(allocator, .dquote, input, pos);
                _ = reader.takeByte() catch unreachable;

                continue;
            },
            else => {
                if (this.string != null) {
                    _ = reader.takeByte() catch unreachable;

                    continue;
                }

                this.string = .{
                    .start = pos,
                };
            },
        }
    }

    try this.tryAppendString(allocator, input, input.len);

    return this;
}

pub fn deinit(this: *Lexer, allocator: std.mem.Allocator) void {
    this.tokens.deinit(allocator);
}

const testing = struct {
    pub fn expectEqualTokens(expected: Token, actual: Token) !void {
        try std.testing.expectEqual(expected.pos, actual.pos);

        const expected_tag = std.meta.activeTag(expected.value);
        const actual_tag = std.meta.activeTag(actual.value);

        try std.testing.expectEqual(expected_tag, actual_tag);

        switch (expected.value) {
            .string => {
                try std.testing.expectEqualStrings(expected.value.string.data, actual.value.string.data);
                try std.testing.expectEqual(expected.value.string.quotes, actual.value.string.quotes);
            },
            else => {},
        }
    }

    pub fn expectEqualTokenSlices(expected: []const Token, actual: []const Token) !void {
        try std.testing.expectEqual(expected.len, actual.len);

        for (0..expected.len) |i| {
            try expectEqualTokens(expected[i], actual[i]);
        }
    }
};

test "Invalid token" {
    const alloc = std.testing.allocator;

    var err: ErrorInfo = .{};

    try std.testing.expectError(Error.InvalidToken, Lexer.parse(alloc, "\" \x00", &err));
    try std.testing.expectEqual(2, err.pos);
}

test "Quotes" {
    const alloc = std.testing.allocator;

    var lexer: Lexer = try .parse(alloc, "\"\" '' \"\"", null);
    defer lexer.deinit(alloc);

    try std.testing.expectEqualSlices(Token, &.{
        .{ .pos = 0, .value = .{ .dquote = .{} } },
        .{ .pos = 1, .value = .{ .dquote = .{} } },
        .{ .pos = 3, .value = .{ .squote = .{} } },
        .{ .pos = 4, .value = .{ .squote = .{} } },
        .{ .pos = 6, .value = .{ .dquote = .{} } },
        .{ .pos = 7, .value = .{ .dquote = .{} } },
    }, lexer.tokens.items);
}

test "Strings" {
    const alloc = std.testing.allocator;

    var lexer: Lexer = try .parse(alloc, "hello world !", null);
    defer lexer.deinit(alloc);

    const expected = [_]Token{
        .{ .pos = 0, .value = .{ .string = .{ .data = "hello", .quotes = .no } } },
        .{ .pos = 6, .value = .{ .string = .{ .data = "world", .quotes = .no } } },
        .{ .pos = 12, .value = .{ .string = .{ .data = "!", .quotes = .no } } },
    };

    try testing.expectEqualTokenSlices(&expected, lexer.tokens.items);
}

test "Quoted strings" {
    const alloc = std.testing.allocator;

    var lexer: Lexer = try .parse(alloc, "'foobar' \"foobar\" foo bar", null);
    defer lexer.deinit(alloc);

    const expected = [_]Token{
        .{ .pos = 0, .value = .squote },
        .{ .pos = 1, .value = .{ .string = .{ .data = "foobar", .quotes = .squote } } },
        .{ .pos = 7, .value = .squote },
        .{ .pos = 9, .value = .dquote },
        .{ .pos = 10, .value = .{ .string = .{ .data = "foobar", .quotes = .dquote } } },
        .{ .pos = 16, .value = .dquote },
        .{ .pos = 18, .value = .{ .string = .{ .data = "foo", .quotes = .no } } },
        .{ .pos = 22, .value = .{ .string = .{ .data = "bar", .quotes = .no } } },
    };

    try testing.expectEqualTokenSlices(&expected, lexer.tokens.items);
}

test "Quoted quotes" {
    const alloc = std.testing.allocator;

    var lexer: Lexer = try .parse(alloc, "\"'foo'\" '\"bar\"'", null);
    defer lexer.deinit(alloc);

    const expected = [_]Token{
        .{ .pos = 0, .value = .dquote },
        .{ .pos = 1, .value = .{ .string = .{ .data = "'foo'", .quotes = .dquote } } },
        .{ .pos = 6, .value = .dquote },
        .{ .pos = 8, .value = .squote },
        .{ .pos = 9, .value = .{ .string = .{ .data = "\"bar\"", .quotes = .squote } } },
        .{ .pos = 14, .value = .squote },
    };

    try testing.expectEqualTokenSlices(&expected, lexer.tokens.items);
}
