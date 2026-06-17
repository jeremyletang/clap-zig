//! Port of clap's git example:
//! https://github.com/clap-rs/clap/blob/master/examples/git.rs
//! Output is verified byte-for-byte against
//! https://github.com/clap-rs/clap/blob/master/examples/git.md (see tests/snapshot_test.zig).

const std = @import("std");
const clap = @import("clap");

const Command = clap.Command;
const Arg = clap.Arg;
const ArgMatches = clap.ArgMatches;

pub fn cli(a: std.mem.Allocator) Command {
    const push_args = &[_]Arg{Arg.fromUsage("-m --message <MESSAGE>", null)};
    return Command.init(a, "git")
        .about("A fictional versioning CLI")
        .subcommandRequired(true)
        .argRequiredElseHelp(true)
        .allowExternalSubcommands(true)
        .subcommand(Command.init(a, "clone")
            .about("Clones repos")
            .arg(Arg.fromUsage("<REMOTE>", "The remote to clone"))
            .argRequiredElseHelp(true))
        .subcommand(Command.init(a, "diff")
            .about("Compare two commits")
            .arg(Arg.fromUsage("base: [COMMIT]", null))
            .arg(Arg.fromUsage("head: [COMMIT]", null))
            .arg(Arg.fromUsage("path: [PATH]", null).last(true))
            .arg(Arg.new("color").long("color").valueName("WHEN")
                .valueParser(&.{ "always", "auto", "never" })
                .numArgs(clap.ValueRange.between(0, 1))
                .requireEquals(true)
                .defaultValue("auto")
                .defaultMissingValue("always")))
        .subcommand(Command.init(a, "push")
            .about("pushes things")
            .arg(Arg.fromUsage("<REMOTE>", "The remote to target"))
            .argRequiredElseHelp(true))
        .subcommand(Command.init(a, "add")
            .about("adds things")
            .argRequiredElseHelp(true)
            .arg(Arg.fromUsage("<PATH>...", "Stuff to add")))
        .subcommand(Command.init(a, "stash")
            .argsConflictsWithSubcommands(true)
            .flattenHelp(true)
            .args(push_args)
            .subcommand(Command.init(a, "push").args(push_args))
            .subcommand(Command.init(a, "pop").arg(Arg.fromUsage("[STASH]", null)))
            .subcommand(Command.init(a, "apply").arg(Arg.fromUsage("[STASH]", null))));
}

/// Parse `argv` and run the program logic, writing all output to `out`.
/// Returns the process exit code (clap help/errors included).
pub fn run(a: std.mem.Allocator, argv: []const []const u8, out: *std.ArrayList(u8)) u8 {
    var cmd = cli(a);
    cmd.buildTree();
    const matches = switch (clap.getMatches(a, &cmd, argv)) {
        .matches => |m| m,
        .err => |e| {
            add(a, out, clap.renderError(a, e));
            return e.kind.exitCode();
        },
    };
    const sub = matches.subcommand().?;
    dispatch(a, out, &cmd, sub);
    return 0;
}

fn dispatch(a: std.mem.Allocator, out: *std.ArrayList(u8), root: *const Command, sub: clap.Subcommand) void {
    const m = sub.matches;
    if (std.mem.eql(u8, sub.name, "clone")) {
        print(a, out, "Cloning {s}\n", .{m.getOne([]const u8, "REMOTE").?});
    } else if (std.mem.eql(u8, sub.name, "diff")) {
        diff(a, out, m);
    } else if (std.mem.eql(u8, sub.name, "push")) {
        print(a, out, "Pushing to {s}\n", .{m.getOne([]const u8, "REMOTE").?});
    } else if (std.mem.eql(u8, sub.name, "add")) {
        print(a, out, "Adding {s}\n", .{debugList(a, m.getMany([]const u8, "PATH"))});
    } else if (std.mem.eql(u8, sub.name, "stash")) {
        stash(a, out, m);
    } else {
        external(a, out, sub);
    }
    _ = root;
}

fn diff(a: std.mem.Allocator, out: *std.ArrayList(u8), m: *const ArgMatches) void {
    const color = m.getOne([]const u8, "color").?;
    var base = m.getOne([]const u8, "base");
    var head = m.getOne([]const u8, "head");
    var path = m.getOne([]const u8, "path");
    if (path == null) {
        path = head;
        head = null;
        if (path == null) {
            path = base;
            base = null;
        }
    }
    print(a, out, "Diffing {s}..{s} {s} (color={s})\n", .{
        base orelse "stage",
        head orelse "worktree",
        path orelse "",
        color,
    });
}

fn stash(a: std.mem.Allocator, out: *std.ArrayList(u8), m: *const ArgMatches) void {
    // default to `push` using stash's own matches, mirroring git.rs
    const name = if (m.subcommand()) |s| s.name else "push";
    const sm = if (m.subcommand()) |s| s.matches else m;
    if (std.mem.eql(u8, name, "apply")) {
        print(a, out, "Applying {s}\n", .{optStr(a, sm.getOne([]const u8, "STASH"))});
    } else if (std.mem.eql(u8, name, "pop")) {
        print(a, out, "Popping {s}\n", .{optStr(a, sm.getOne([]const u8, "STASH"))});
    } else {
        print(a, out, "Pushing {s}\n", .{optStr(a, sm.getOne([]const u8, "message"))});
    }
}

fn external(a: std.mem.Allocator, out: *std.ArrayList(u8), sub: clap.Subcommand) void {
    const args = sub.matches.getMany([]const u8, clap.external_id);
    print(a, out, "Calling out to {s} with {s}\n", .{ debugStr(a, sub.name), debugList(a, args) });
}

// ----- output helpers -----

fn add(a: std.mem.Allocator, out: *std.ArrayList(u8), s: []const u8) void {
    out.appendSlice(a, s) catch @panic("OOM");
}

fn print(a: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) void {
    add(a, out, std.fmt.allocPrint(a, fmt, args) catch @panic("OOM"));
}

// ----- Rust Debug-style formatting (to match git.md exactly) -----

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

    // toSlice yields []const [:0]const u8; copy to []const u8 (each element coerces)
    const raw = try init.minimal.args.toSlice(a);
    var argv: std.ArrayList([]const u8) = .empty;
    for (raw) |arg0| try argv.append(a, arg0);

    var out: std.ArrayList(u8) = .empty;
    const code = run(a, argv.items[1..], &out);

    const file = if (code == 0) std.Io.File.stdout() else std.Io.File.stderr();
    try file.writeStreamingAll(init.io, out.items);
    std.process.exit(code);
}
