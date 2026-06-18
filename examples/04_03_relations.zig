//! Port of https://github.com/clap-rs/clap/blob/master/examples/tutorial_builder/04_03_relations.rs

const std = @import("std");
const clap = @import("clap");
const harness = @import("harness");

pub fn cli(a: std.mem.Allocator) clap.Command {
    return clap.Command.init(a, "04_03_relations")
        .about(harness.pkg_about)
        .version(harness.pkg_version)
        .arg(clap.Arg.fromUsage("--set-ver <VER>", "set version manually"))
        .arg(clap.Arg.fromUsage("--major", "auto inc major"))
        .arg(clap.Arg.fromUsage("--minor", "auto inc minor"))
        .arg(clap.Arg.fromUsage("--patch", "auto inc patch"))
        .group(clap.ArgGroup.new("vers").required(true).args(&.{ "set-ver", "major", "minor", "patch" }))
        .arg(clap.Arg.fromUsage("[INPUT_FILE]", "some regular input").group("input"))
        .arg(clap.Arg.fromUsage("--spec-in <SPEC_IN>", "some special input argument").group("input"))
        .arg(clap.Arg.fromUsage("config: -c <CONFIG>", null).requires("input"));
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

    harness.print(a, out, "Version: {s}\n", .{version(a, m)});

    if (m.isPresent("config")) {
        const input = m.getOne([]const u8, "INPUT_FILE") orelse m.getOne([]const u8, "spec-in").?;
        harness.print(a, out, "Doing work using input {s} and config {s}\n", .{ input, m.getOne([]const u8, "config").? });
    }
    return 0;
}

fn version(a: std.mem.Allocator, m: *const clap.ArgMatches) []const u8 {
    if (m.getOne([]const u8, "set-ver")) |v| return v;
    // start from 1.2.3 and bump the requested component
    var major: u32 = 1;
    var minor: u32 = 2;
    var patch: u32 = 3;
    if (m.getFlag("major")) major += 1 else if (m.getFlag("minor")) minor += 1 else patch += 1;
    return std.fmt.allocPrint(a, "{d}.{d}.{d}", .{ major, minor, patch }) catch @panic("OOM");
}

pub fn main(init: std.process.Init) !void {
    try harness.execMain(init, run);
}
