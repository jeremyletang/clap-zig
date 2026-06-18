//! Port of https://github.com/clap-rs/clap/blob/master/examples/tutorial_builder/03_05_default_values.rs

const std = @import("std");
const clap = @import("clap");
const harness = @import("harness");

pub fn cli(a: std.mem.Allocator) clap.Command {
    return clap.Command.init(a, "03_05_default_values")
        .about(harness.pkg_about)
        .version(harness.pkg_version)
        .arg(clap.Arg.fromUsage("[PORT]", null).defaultValue("2020"));
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
    harness.print(a, out, "port: {d}\n", .{m.getOne(u16, "PORT").?});
    return 0;
}

pub fn main(init: std.process.Init) !void {
    try harness.execMain(init, run);
}
