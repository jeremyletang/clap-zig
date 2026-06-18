//! Port of https://github.com/clap-rs/clap/blob/master/examples/tutorial_builder/04_02_validate.rs

const std = @import("std");
const clap = @import("clap");
const harness = @import("harness");

pub fn cli(a: std.mem.Allocator) clap.Command {
    return clap.Command.init(a, "04_02_validate")
        .about(harness.pkg_about)
        .version(harness.pkg_version)
        .arg(clap.Arg.fromUsage("<PORT>", "Network port to use")
            .valueParserFn(&portInRange));
}

fn portInRange(a: std.mem.Allocator, s: []const u8) clap.ParseResult {
    const port = std.fmt.parseInt(usize, s, 10) catch
        return .{ .invalid = std.fmt.allocPrint(a, "`{s}` isn't a port number", .{s}) catch @panic("OOM") };
    if (port >= 1 and port <= 65535) return .ok;
    return .{ .invalid = "port not in range 1-65535" };
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
    harness.print(a, out, "PORT = {d}\n", .{m.getOne(u16, "PORT").?});
    return 0;
}

pub fn main(init: std.process.Init) !void {
    try harness.execMain(init, run);
}
