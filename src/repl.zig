const std = @import("std");
const Shell = @import("shell.zig");

shell: *Shell,

pub fn nextline(this: *@This()) !bool {
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

const Repl = @This();

test "EOF" {
    const testing = @import("testing.zig");

    const alloc = std.testing.allocator;
    var streams: testing.Streams = try .init(alloc, .{});
    defer streams.deinit(alloc);

    var shell: Shell = .init(alloc, &streams.stdin, &streams.stdout, &streams.stderr);
    defer shell.deinit(alloc);

    var repl: Repl = .{ .shell = &shell };
    try std.testing.expect(try repl.nextline() == false);
}

test "Prompt" {
    const testing = @import("testing.zig");

    const alloc = std.testing.allocator;
    var streams: testing.Streams = try .init(alloc, .{});
    defer streams.deinit(alloc);

    var shell: Shell = .init(alloc, &streams.stdin, &streams.stdout, &streams.stderr);
    defer shell.deinit(alloc);

    var repl: Repl = .{ .shell = &shell };
    try std.testing.expect(try repl.nextline() == false);

    try std.testing.expectEqualStrings(streams.stderr_buf[0..3], "$ \n");
}
