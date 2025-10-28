// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
