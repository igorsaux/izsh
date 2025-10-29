// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const io = @import("io.zig");
const types = @import("types.zig");
const builtins = @import("builtins.zig");

pub const Executor = struct {
    pub const Error = error{CommandNotFound};

    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// returns null if the command not found
        execute: *const fn (*anyopaque, argc: usize, argv: [*:null]const ?[*:0]const u8) ?types.ReturnCode,
    };

    pub inline fn execute(this: Executor, argc: usize, argv: [*:null]const ?[*:0]const u8) Error!types.ReturnCode {
        return this.vtable.execute(this.ptr, argc, argv) orelse return Error.CommandNotFound;
    }
};

pub const EmptyExecutor = struct {
    pub fn execute(context: *anyopaque, argc: usize, argv: [*:null]const ?[*:0]const u8) ?types.ReturnCode {
        _ = context;
        _ = argc;
        _ = argv;

        return null;
    }

    pub fn executor(this: *EmptyExecutor) Executor {
        return .{
            .ptr = this,
            .vtable = &.{
                .execute = &EmptyExecutor.execute,
            },
        };
    }
};

pub const BuiltinsExecutor = struct {
    allocator: std.mem.Allocator,
    streams: io.Streams,
    chained: ?Executor = null,

    pub fn init(allocator: std.mem.Allocator, streams: io.Streams, chained: ?Executor) BuiltinsExecutor {
        return .{
            .allocator = allocator,
            .streams = streams,
            .chained = chained,
        };
    }

    pub fn execute(context: *anyopaque, argc: usize, argv: [*:null]const ?[*:0]const u8) ?types.ReturnCode {
        if (argc == 0) {
            return null;
        }

        const this: *BuiltinsExecutor = @ptrCast(@alignCast(context));

        if (std.mem.eql(u8, std.mem.span(argv[0].?), "echo")) {
            return builtins.echo(this.streams, argc, argv) catch return null;
        }

        if (this.chained) |chained| {
            return chained.execute(argc, argv) catch return null;
        }

        return null;
    }

    pub fn executor(this: *BuiltinsExecutor) Executor {
        return .{
            .ptr = this,
            .vtable = &.{
                .execute = &BuiltinsExecutor.execute,
            },
        };
    }
};
