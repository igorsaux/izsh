// Copyright (C) 2025 Igor Spichkin
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const Shell = @import("../shell.zig");
const types = @import("../types.zig");

pub fn run(shell: *Shell, argc: usize, argv: [*:null]const ?[*:0]const u8) !types.ReturnCode {
    var print_newline: bool = true;

    var from: usize = 1;

    if (argc > 1 and std.mem.eql(u8, std.mem.span(argv[1].?), "-n")) {
        print_newline = false;
        from += 1;
    }

    for (from..argc) |i| {
        shell.stdout.writeAll(std.mem.span(argv[i].?)) catch {};

        if (i < argc - 1) {
            shell.stdout.writeByte(' ') catch {};
        }
    }

    if (print_newline) {
        shell.stdout.writeByte('\n') catch {};
    }

    shell.stdout.flush() catch {};

    return 0;
}
