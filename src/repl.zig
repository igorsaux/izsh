// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const Shell = @import("shell.zig");
const Lexer = @import("lexer.zig");
const types = @import("types.zig");
const executors = @import("executors.zig");

executor: executors.Executor,
shell: *Shell,

const Repl = @This();

pub fn readLine(this: *Repl, allocator: std.mem.Allocator) !bool {
    var shell = this.shell;

    next_line: while (true) {
        try shell.stderr.writeAll("$ ");
        try shell.stderr.flush();

        var input: std.ArrayList(u8) = try .initCapacity(allocator, 1024);
        defer input.deinit(allocator);

        var byte: [1]u8 = .{0};

        while (byte[0] != '\n') {
            shell.stdin.readSliceAll(&byte) catch |err| switch (err) {
                std.Io.Reader.Error.EndOfStream => {
                    shell.stderr.writeAll("\n") catch {};
                    shell.stderr.flush() catch {};

                    return false;
                },
                else => {
                    return err;
                },
            };

            if (byte[0] != '\n') {
                try input.append(allocator, byte[0]);
            }
        }

        if (input.items.len == 1) {
            continue :next_line;
        }

        // run the command
        {
            var err_info: Lexer.ErrorInfo = .{};
            var lexer = Lexer.parse(allocator, input.items, &err_info) catch |err| switch (err) {
                Lexer.Error.InvalidToken => {
                    shell.stderr.print("invalid token at {d}\n", .{err_info.pos}) catch {};
                    shell.stderr.flush() catch {};

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

            for (args[0 .. args.len - 1], 0..) |chr, i| {
                if (chr != 0) {
                    continue;
                }

                argv[p] = @ptrCast(&args.ptr[i + 1]);
                p += 1;
            }

            _ = this.executor.execute(argc, argv) catch {
                shell.stderr.print("command not found: {s}\n", .{lexer.tokens.items[0].value.string.data}) catch {};
                shell.stderr.flush() catch {};
            };
        }
    }

    return true;
}

test "EOF" {
    const testing = @import("testing.zig");

    const alloc = std.testing.allocator;
    var streams: testing.Streams = try .init(alloc, .{});
    defer streams.deinit(alloc);

    var shell: Shell = .init(alloc, &streams.stdin, &streams.stdout, &streams.stderr);
    defer shell.deinit(alloc);

    var executor: executors.EmptyExecutor = .{};
    var repl: Repl = .{ .executor = executor.executor(), .shell = &shell };

    try std.testing.expectEqual(false, try repl.readLine(alloc));
}

test "Prompt" {
    const testing = @import("testing.zig");

    const alloc = std.testing.allocator;
    var streams: testing.Streams = try .init(alloc, .{});
    defer streams.deinit(alloc);

    var shell: Shell = .init(alloc, &streams.stdin, &streams.stdout, &streams.stderr);
    defer shell.deinit(alloc);

    var executor: executors.EmptyExecutor = .{};
    var repl: Repl = .{ .executor = executor.executor(), .shell = &shell };

    try std.testing.expectEqual(false, try repl.readLine(alloc));
    try std.testing.expectEqualStrings("$ \n", streams.stderr_buf[0..3]);
}

test "Echo builtin" {
    const testing = @import("testing.zig");

    const alloc = std.testing.allocator;
    var streams: testing.Streams = try .init(alloc, .{});
    defer streams.deinit(alloc);

    try streams.writeLine("echo \'Hello, world!\'");

    var shell: Shell = .init(alloc, &streams.stdin, &streams.stdout, &streams.stderr);
    defer shell.deinit(alloc);

    var executor: executors.BuiltinsExecutor = .init(alloc, &shell, null);
    var repl: Repl = .{ .executor = executor.executor(), .shell = &shell };

    try std.testing.expectEqual(false, try repl.readLine(alloc));
    try std.testing.expectEqualStrings("Hello, world!\n", streams.stdout_buf[0..streams.stdout.end]);
}
