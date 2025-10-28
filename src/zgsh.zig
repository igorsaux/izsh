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

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        _ = allocator;

        this.stdout.flush() catch {};
        this.stderr.flush() catch {};
    }
};

pub const Repl = struct {
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
};
