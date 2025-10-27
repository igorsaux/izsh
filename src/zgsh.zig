const std = @import("std");

pub const Shell = struct {
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

    pub fn execute(this: *@This()) !void {
        try this.stderr.writeAll("$ ");
        try this.stderr.flush();

        var byte: [1]u8 = undefined;

        while (byte[0] != '\n') {
            try this.stdin.readSliceAll(&byte);
        }
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        _ = allocator;

        this.stdout.flush() catch {};
        this.stderr.flush() catch {};
    }
};
