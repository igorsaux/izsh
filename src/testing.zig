const std = @import("std");

pub const Streams = struct {
    pub const Options = struct {
        stdin_size: usize = 256,
        stdout_size: usize = 256,
        stderr_size: usize = 256,
    };

    stdin_buf: []u8,
    stdout_buf: []u8,
    stderr_buf: []u8,
    stdin: std.Io.Reader,
    stdout: std.Io.Writer,
    stderr: std.Io.Writer,

    pub fn init(allocator: std.mem.Allocator, options: Options) !@This() {
        var streams: @This() = undefined;

        streams.stdin_buf = try allocator.alloc(u8, options.stdin_size);
        errdefer allocator.free(streams.stdin_buf);

        streams.stdout_buf = try allocator.alloc(u8, options.stdout_size);
        errdefer allocator.free(streams.stdout_buf);

        streams.stderr_buf = try allocator.alloc(u8, options.stderr_size);
        errdefer allocator.free(streams.stderr_buf);

        streams.stdin = .fixed(streams.stdin_buf);
        streams.stdout = .fixed(streams.stdout_buf);
        streams.stderr = .fixed(streams.stderr_buf);

        return streams;
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(this.stdin_buf);
        allocator.free(this.stdout_buf);
        allocator.free(this.stderr_buf);
    }
};
