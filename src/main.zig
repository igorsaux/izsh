// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const zgsh = @import("zgsh");

pub fn main() !void {
    const gpa = std.heap.DebugAllocator(.{});
    var alloc = gpa.init;
    defer _ = alloc.deinit();

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
        alloc.allocator(),
        &stdin_reader.interface,
        &stdout_writer.interface,
        &stderr_writer.interface,
    );
    defer shell.deinit(alloc.allocator());

    var repl: zgsh.Repl = try .init(alloc.allocator(), &shell);
    defer repl.deinit(alloc.allocator());

    while (try repl.readline()) {}
}
