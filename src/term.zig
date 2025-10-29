// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const builtin = @import("builtin");

pub const Buffer = @import("term/buffer.zig");

pub const Colors = enum(u8) {
    mono,
};

pub const Error = error{ WriteFailed, ReadFailed };

pub const Terminal = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        getch: *const fn (*anyopaque) ?u8,
        addnstr: *const fn (*anyopaque, []const u8) bool,
    };

    pub fn getch(this: Terminal) !u8 {
        return this.vtable.getch(this.ptr) orelse return Error.ReadFailed;
    }

    pub fn addnstr(this: Terminal, str: []const u8) !void {
        if (!this.vtable.addnstr(this.ptr, str)) {
            return Error.WriteFailed;
        }
    }
};

pub const NativeTag = enum(u8) {
    ncurses,

    fn getNativeBackend() NativeTag {
        const os: std.Target.Os.Tag = builtin.os.tag;

        if (os.isBSD() or os.isDarwin() or os.isSolarish() or os == .linux) {
            return .ncurses;
        }

        @compileError("backend not implemented");
    }
};

pub const Native = switch (NativeTag.getNativeBackend()) {
    .ncurses => @import("term/ncurses.zig"),
};
