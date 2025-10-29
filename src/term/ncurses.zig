// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const c = @cImport({
    @cInclude("ncurses.h");
});
const term = @import("../term.zig");

pub const Error = error{Unknown};
pub const tag: term.NativeTag = .termios;

const NCurses = @This();

pub fn init(this: *NCurses) Error!void {
    _ = this;

    if (c.initscr() == null) {
        return Error.Unknown;
    }

    if (c.raw() != c.OK) {
        return Error.Unknown;
    }
}

pub fn getch(ctx: *anyopaque) ?u8 {
    _ = ctx;

    const ret: c_int = c.getch();

    if (ret == c.ERR) {
        return null;
    }

    std.debug.assert(ret >= 0);
    std.debug.assert(ret <= std.math.maxInt(u8));

    return @intCast(ret);
}

pub fn addnstr(ctx: *anyopaque, str: []const u8) bool {
    _ = ctx;

    std.debug.assert(str.len <= std.math.maxInt(c_int));

    if (c.addnstr(str.ptr, @intCast(str.len)) == c.ERR) {
        return false;
    }

    return true;
}

pub fn terminal(this: *NCurses) term.Terminal {
    return .{
        .ptr = this,
        .vtable = &.{
            .getch = &NCurses.getch,
            .addnstr = &NCurses.addnstr,
        },
    };
}

pub fn deinit(this: *NCurses) !void {
    _ = this;

    if (c.isendwin()) {
        return;
    }

    if (c.endwin() != c.OK) {
        return Error.Unknown;
    }
}
