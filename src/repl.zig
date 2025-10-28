// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const Shell = @import("shell.zig");

shell: *Shell,
input: std.ArrayList(u8),

const Repl = @This();

pub fn init(allocator: std.mem.Allocator, shell: *Shell) !Repl {
    return .{
        .shell = shell,
        .input = try .initCapacity(allocator, 1024),
    };
}

pub fn readline(this: *Repl) !bool {
    var shell = this.shell;

    try shell.stderr.writeAll("$ ");
    try shell.stderr.flush();

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
    }

    return true;
}

pub fn deinit(this: *Repl, allocator: std.mem.Allocator) void {
    this.input.deinit(allocator);
}

test "EOF" {
    const testing = @import("testing.zig");

    const alloc = std.testing.allocator;
    var streams: testing.Streams = try .init(alloc, .{});
    defer streams.deinit(alloc);

    var shell: Shell = .init(alloc, &streams.stdin, &streams.stdout, &streams.stderr);
    defer shell.deinit(alloc);

    var repl: Repl = try .init(alloc, &shell);
    defer repl.deinit(alloc);

    try std.testing.expectEqual(false, try repl.readline());
}

test "Prompt" {
    const testing = @import("testing.zig");

    const alloc = std.testing.allocator;
    var streams: testing.Streams = try .init(alloc, .{});
    defer streams.deinit(alloc);

    var shell: Shell = .init(alloc, &streams.stdin, &streams.stdout, &streams.stderr);
    defer shell.deinit(alloc);

    var repl: Repl = try .init(alloc, &shell);
    defer repl.deinit(alloc);

    try std.testing.expectEqual(false, try repl.readline());
    try std.testing.expectEqualStrings("$ \n", streams.stderr_buf[0..3]);
}
