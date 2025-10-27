const std = @import("std");
const zgsh = @import("zgsh");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const stdin = std.fs.File.stdin();
    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader: std.fs.File.Reader = stdin.reader(&stdin_buf);

    const stdout = std.fs.File.stdout();
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer: std.fs.File.Writer = stdout.writer(&stdout_buf);

    const stderr = std.fs.File.stderr();
    var stderr_buf: [1024]u8 = undefined;
    var stderr_writer: std.fs.File.Writer = stderr.writer(&stderr_buf);

    var shell = zgsh.Shell.init(
        alloc,
        &stdin_reader.interface,
        &stdout_writer.interface,
        &stderr_writer.interface,
    );
    defer shell.deinit(alloc);

    while (true) {
        try shell.execute();
    }
}
