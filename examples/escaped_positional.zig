//! Port of clap's escaped-positional example:
//! https://github.com/clap-rs/clap/blob/master/examples/escaped-positional.rs
//! Output is verified byte-for-byte against
//! https://github.com/clap-rs/clap/blob/master/examples/escaped-positional.md

const std = @import("std");
const clap = @import("clap");
const harness = @import("harness");

const Command = clap.Command;
const Arg = clap.Arg;

pub fn cli(a: std.mem.Allocator) Command {
    return Command.init(a, "escaped-positional")
        .about("A simple to use, efficient, and full-featured Command Line Argument Parser")
        .version("4.5.40")
        .arg(Arg.fromUsage("eff: -f", null))
        .arg(Arg.fromUsage("pea: -p <PEAR>", null))
        .arg(Arg.fromUsage("slop: [SLOP]", null)
            .numArgs(clap.ValueRange.atLeast(1))
            .last(true));
}

pub fn run(a: std.mem.Allocator, argv: []const []const u8, out: *std.ArrayList(u8)) u8 {
    var cmd = cli(a);
    cmd.buildTree();
    const m = switch (clap.getMatches(a, &cmd, argv)) {
        .matches => |mm| mm,
        .err => |e| {
            harness.print(a, out, "{s}", .{clap.renderError(a, e)});
            return e.kind.exitCode();
        },
    };
    harness.print(a, out, "-f used: {s}\n", .{if (m.getFlag("eff")) "true" else "false"});
    harness.print(a, out, "-p's value: {s}\n", .{harness.optOr(m.getOne([]const u8, "pea"), "(none)")});
    harness.print(a, out, "'slops' values: {s}\n", .{harness.list(a, m.getMany([]const u8, "slop"))});
    return 0;
}

pub fn main(init: std.process.Init) !void {
    try harness.execMain(init, run);
}
