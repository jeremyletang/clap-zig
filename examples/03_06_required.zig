//! Port of https://github.com/clap-rs/clap/blob/master/examples/tutorial_builder/03_06_required.rs

const std = @import("std");
const clap = @import("clap");
const harness = @import("harness");

pub fn cli(a: std.mem.Allocator) clap.Command {
    return clap.Command.init(a, "03_06_required")
        .about(harness.pkg_about)
        .version(harness.pkg_version)
        .arg(clap.Arg.new("name").required(true));
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
    harness.print(a, out, "name: {s}\n", .{m.getOne([]const u8, "name").?});
    return 0;
}

pub fn main(init: std.process.Init) !void {
    try harness.execMain(init, run);
}
