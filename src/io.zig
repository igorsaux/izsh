// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");

pub const Streams = struct {
    stdin: *std.Io.Reader,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
};

pub const HeapStreams = struct {
    stdin_buffer: []u8,
    stdout_buffer: []u8,
    stderr_buffer: []u8,
    stdin: std.Io.Reader,
    stdout: std.Io.Writer,
    stderr: std.Io.Writer,

    pub fn init(allocator: std.mem.Allocator, size: usize) error{OutOfMemory}!HeapStreams {
        var this: HeapStreams = undefined;

        this.stdin_buffer = try allocator.alloc(u8, size);
        errdefer allocator.free(this.stdin_buffer);

        this.stdout_buffer = try allocator.alloc(u8, size);
        errdefer allocator.free(this.stdout_buffer);

        this.stderr_buffer = try allocator.alloc(u8, size);
        errdefer allocator.free(this.stderr_buffer);

        this.stdin = .fixed(this.stdin_buffer);
        this.stdout = .fixed(this.stdout_buffer);
        this.stderr = .fixed(this.stderr_buffer);

        return this;
    }

    pub fn streams(this: *HeapStreams) Streams {
        return .{
            .stdin = &this.stdin,
            .stdout = &this.stdout,
            .stderr = &this.stderr,
        };
    }

    pub fn deinit(this: *HeapStreams, allocator: std.mem.Allocator) void {
        allocator.free(this.stdin_buffer);
        allocator.free(this.stdout_buffer);
        allocator.free(this.stderr_buffer);
    }
};

pub const FileStreams = struct {
    stdin: std.fs.File.Reader,
    stdout: std.fs.File.Writer,
    stderr: std.fs.File.Writer,

    pub fn init(
        stdin: std.fs.File,
        stdin_buffer: []u8,
        stdout: std.fs.File,
        stdout_buffer: []u8,
        stderr: std.fs.File,
        stderr_buffer: []u8,
    ) FileStreams {
        const this: FileStreams = .{
            .stdin = stdin.reader(stdin_buffer),
            .stdout = stdout.writer(stdout_buffer),
            .stderr = stderr.writer(stderr_buffer),
        };

        return this;
    }

    pub fn streams(this: *FileStreams) Streams {
        return .{
            .stdin = &this.stdin.interface,
            .stdout = &this.stdout.interface,
            .stderr = &this.stderr.interface,
        };
    }
};
