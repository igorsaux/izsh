// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const term = @import("../term.zig");

input: *std.Io.Reader,
output: *std.Io.Writer,

const Buffer = @This();

pub fn getch(ctx: *anyopaque) ?u8 {
    var this: *Buffer = @ptrCast(@alignCast(ctx));
    var byte: [1]u8 = undefined;

    this.input.readSliceAll(&byte) catch return null;

    return byte[0];
}

pub fn addnstr(ctx: *anyopaque, str: []const u8) bool {
    var this: *Buffer = @ptrCast(@alignCast(ctx));

    this.output.writeAll(str) catch return false;
    this.output.flush() catch return false;

    return true;
}

pub fn terminal(this: *Buffer) term.Terminal {
    return .{
        .ptr = this,
        .vtable = &.{
            .getch = &Buffer.getch,
            .addnstr = &Buffer.addnstr,
        },
    };
}
