// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const izsh = @import("izsh");

pub fn main() !void {
    const gpa = std.heap.DebugAllocator(.{});
    var alloc = gpa.init;
    defer _ = alloc.deinit();

    const stdin = std.fs.File.stdin();
    var stdin_buffer: [1024]u8 = undefined;

    const stdout = std.fs.File.stdout();
    var stdout_buffer: [1024]u8 = undefined;

    const stderr = std.fs.File.stderr();
    var stderr_buffer: [1024]u8 = undefined;

    var file_streams = izsh.io.FileStreams.init(stdin, &stdin_buffer, stdout, &stdout_buffer, stderr, &stderr_buffer);

    var builtins_executor: izsh.executors.BuiltinsExecutor = .init(alloc.allocator(), file_streams.streams(), null);
    var repl: izsh.Repl = .{ .executor = builtins_executor.executor(), .streams = file_streams.streams() };

    while (try repl.readLine(alloc.allocator())) {}
}
