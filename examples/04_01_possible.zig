//! Port of https://github.com/clap-rs/clap/blob/master/examples/tutorial_builder/04_01_possible.rs

const std = @import("std");
const clap = @import("clap");
const harness = @import("harness");

pub fn cli(a: std.mem.Allocator) clap.Command {
    return clap.Command.init(a, "04_01_possible")
        .about(harness.pkg_about)
        .version(harness.pkg_version)
        .arg(clap.Arg.fromUsage("<MODE>", "What mode to run the program in")
        .valueParser(&.{ "fast", "slow" }));
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
    const mode = m.getOne([]const u8, "MODE").?;
    if (std.mem.eql(u8, mode, "fast")) {
        harness.print(a, out, "Hare\n", .{});
    } else {
        harness.print(a, out, "Tortoise\n", .{});
    }
    return 0;
}

pub fn main(init: std.process.Init) !void {
    try harness.execMain(init, run);
}
