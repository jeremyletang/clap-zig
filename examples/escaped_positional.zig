//! Port of clap's escaped-positional example:
//! https://github.com/clap-rs/clap/blob/master/examples/escaped-positional.rs
//! Output is verified byte-for-byte against
//! https://github.com/clap-rs/clap/blob/master/examples/escaped-positional.md

const std = @import("std");
const clap = @import("clap");

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
            add(a, out, clap.renderError(a, e));
            return e.kind.exitCode();
        },
    };
    print(a, out, "-f used: {s}\n", .{if (m.getFlag("eff")) "true" else "false"});
    print(a, out, "-p's value: {s}\n", .{optStr(a, m.getOne([]const u8, "pea"))});
    print(a, out, "'slops' values: {s}\n", .{debugList(a, m.getMany([]const u8, "slop"))});
    return 0;
}

// ----- output + Rust Debug-style formatting -----

fn add(a: std.mem.Allocator, out: *std.ArrayList(u8), s: []const u8) void {
    out.appendSlice(a, s) catch @panic("OOM");
}

fn print(a: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) void {
    add(a, out, std.fmt.allocPrint(a, fmt, args) catch @panic("OOM"));
}

fn debugStr(a: std.mem.Allocator, s: []const u8) []const u8 {
    return std.fmt.allocPrint(a, "\"{s}\"", .{s}) catch @panic("OOM");
}

fn optStr(a: std.mem.Allocator, v: ?[]const u8) []const u8 {
    return if (v) |s| std.fmt.allocPrint(a, "Some({s})", .{debugStr(a, s)}) catch @panic("OOM") else "None";
}

fn debugList(a: std.mem.Allocator, vals: ?[]const []const u8) []const u8 {
    var b: std.ArrayList(u8) = .empty;
    b.appendSlice(a, "[") catch @panic("OOM");
    if (vals) |list| {
        for (list, 0..) |v, i| {
            if (i != 0) b.appendSlice(a, ", ") catch @panic("OOM");
            b.appendSlice(a, debugStr(a, v)) catch @panic("OOM");
        }
    }
    b.appendSlice(a, "]") catch @panic("OOM");
    return b.items;
}

pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    const raw = try init.minimal.args.toSlice(a);
    var argv: std.ArrayList([]const u8) = .empty;
    for (raw) |arg0| try argv.append(a, arg0);

    var out: std.ArrayList(u8) = .empty;
    const code = run(a, argv.items[1..], &out);

    const file = if (code == 0) std.Io.File.stdout() else std.Io.File.stderr();
    try file.writeStreamingAll(init.io, out.items);
    std.process.exit(code);
}
