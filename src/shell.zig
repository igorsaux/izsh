const std = @import("std");

stdin: *std.Io.Reader,
stdout: *std.Io.Writer,
stderr: *std.Io.Writer,

pub fn init(
    allocator: std.mem.Allocator,
    stdin: *std.Io.Reader,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
) @This() {
    _ = allocator;

    return .{
        .stdin = stdin,
        .stdout = stdout,
        .stderr = stderr,
    };
}

pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
    _ = allocator;

    this.stdout.flush() catch {};
    this.stderr.flush() catch {};
}
