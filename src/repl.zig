// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const Lexer = @import("lexer.zig");
const types = @import("types.zig");
const io = @import("io.zig");
const executors = @import("executors.zig");
const term = @import("term.zig");

executor: executors.Executor,
backend: term.Terminal,

const Repl = @This();

pub fn readLine(this: *Repl, allocator: std.mem.Allocator) !bool {
    next_line: while (true) {
        try this.backend.addnstr("$ ");

        var input: std.ArrayList(u8) = try .initCapacity(allocator, 1024);
        defer input.deinit(allocator);

        var chr: u8 = 0;

        while (chr != '\n') {
            chr = this.backend.getch() catch {
                this.backend.addnstr("\n") catch {};

                return false;
            };

            // TODO: parse sequences
            if (chr != '\n') {
                if (std.ascii.isPrint(chr)) {
                    try this.backend.addnstr(&.{chr});
                }

                try input.append(allocator, chr);
            }
        }

        try this.backend.addnstr("\n");

        if (input.items.len == 1) {
            continue :next_line;
        }

        // run the command
        {
            var err_info: Lexer.ErrorInfo = .{};
            var lexer = Lexer.parse(allocator, input.items, &err_info) catch |err| switch (err) {
                Lexer.Error.InvalidToken => {
                    // TODO: streaming
                    var buf: [512]u8 = undefined;
                    var buf_writer: std.Io.Writer = .fixed(&buf);

                    try buf_writer.print("invalid token at {}\n", .{err_info.pos});
                    try this.backend.addnstr(buf[0..buf_writer.end]);

                    return err;
                },
                else => return err,
            };
            defer lexer.deinit(allocator);

            if (lexer.tokens.items.len == 0) {
                continue :next_line;
            }

            const argc: usize = lexer.tokens.items.len;
            var args_len: usize = argc;

            for (lexer.tokens.items) |tok| {
                const value: Lexer.TokenValue = tok.value;

                args_len += value.string.data.len;
            }

            const args: []u8 = try allocator.alloc(u8, args_len);
            defer allocator.free(args);

            var args_writer: std.Io.Writer = .fixed(args);

            for (lexer.tokens.items) |tok| {
                const value: Lexer.TokenValue = tok.value;

                args_writer.writeAll(value.string.data) catch unreachable;
                args_writer.writeByte(0) catch unreachable;
            }

            args_writer.flush() catch unreachable;

            const argv: [:null]?[*:0]u8 = try allocator.allocSentinel(?[*:0]u8, argc, null);
            defer allocator.free(argv);

            argv[0] = @ptrCast(&args.ptr[0]);

            var p: usize = 1;

            for (args[0 .. args.len - 1], 0..) |c, i| {
                if (c != 0) {
                    continue;
                }

                argv[p] = @ptrCast(&args.ptr[i + 1]);
                p += 1;
            }

            _ = this.executor.execute(argc, argv) catch {
                // TODO: streaming
                var buf: [512]u8 = undefined;
                var buf_writer: std.Io.Writer = .fixed(&buf);

                try buf_writer.print("command not found: {s}\n", .{lexer.tokens.items[0].value.string.data});

                try this.backend.addnstr(buf[0..buf_writer.end]);
            };
        }
    }

    return true;
}

test "EOF" {
    const alloc = std.testing.allocator;

    var heap_streams: io.HeapStreams = try .init(alloc, 1024);
    defer heap_streams.deinit(alloc);

    var executor: executors.EmptyExecutor = .{};
    var backend: term.Buffer = .{ .input = &heap_streams.stdin, .output = &heap_streams.stderr };

    var repl: Repl = .{
        .executor = executor.executor(),
        .backend = backend.terminal(),
    };

    try std.testing.expectEqual(false, try repl.readLine(alloc));
}

test "Prompt" {
    const alloc = std.testing.allocator;

    var heap_streams: io.HeapStreams = try .init(alloc, 1024);
    defer heap_streams.deinit(alloc);

    var executor: executors.EmptyExecutor = .{};
    var backend: term.Buffer = .{ .input = &heap_streams.stdin, .output = &heap_streams.stderr };

    var repl: Repl = .{
        .executor = executor.executor(),
        .backend = backend.terminal(),
    };

    try std.testing.expectEqual(false, try repl.readLine(alloc));
    try std.testing.expectEqualStrings("$ \n", heap_streams.stderr_buffer[0..3]);
}

test "Echo builtin" {
    const alloc = std.testing.allocator;

    var heap_streams: io.HeapStreams = try .init(alloc, 1024);
    defer heap_streams.deinit(alloc);

    var stdin_writer: std.Io.Writer = .fixed(heap_streams.stdin_buffer);
    try stdin_writer.writeAll("echo \'Hello, world!\'\n");

    var executor: executors.BuiltinsExecutor = .init(alloc, heap_streams.streams(), null);
    var backend: term.Buffer = .{ .input = &heap_streams.stdin, .output = &heap_streams.stderr };

    var repl: Repl = .{
        .executor = executor.executor(),
        .backend = backend.terminal(),
    };

    try std.testing.expectEqual(false, try repl.readLine(alloc));
    try std.testing.expectEqualStrings("Hello, world!\n", heap_streams.stdout_buffer[0..heap_streams.stdout.end]);
}
