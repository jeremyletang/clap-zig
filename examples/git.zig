//! Port of clap's git example:
//! https://github.com/clap-rs/clap/blob/master/examples/git.rs
//! Output is verified byte-for-byte against
//! https://github.com/clap-rs/clap/blob/master/examples/git.md (see tests/snapshot_test.zig).

const std = @import("std");
const clap = @import("clap");
const harness = @import("harness");

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
            harness.print(a, out, "{s}", .{clap.renderError(a, e)});
            return e.kind.exitCode();
        },
    };
    dispatch(a, out, matches.subcommand().?);
    return 0;
}

fn dispatch(a: std.mem.Allocator, out: *std.ArrayList(u8), sub: clap.Subcommand) void {
    const m = sub.matches;
    if (std.mem.eql(u8, sub.name, "clone")) {
        harness.print(a, out, "Cloning {s}\n", .{m.getOne([]const u8, "REMOTE").?});
    } else if (std.mem.eql(u8, sub.name, "diff")) {
        diff(a, out, m);
    } else if (std.mem.eql(u8, sub.name, "push")) {
        harness.print(a, out, "Pushing to {s}\n", .{m.getOne([]const u8, "REMOTE").?});
    } else if (std.mem.eql(u8, sub.name, "add")) {
        harness.print(a, out, "Adding {s}\n", .{harness.list(a, m.getMany([]const u8, "PATH"))});
    } else if (std.mem.eql(u8, sub.name, "stash")) {
        stash(a, out, m);
    } else {
        const args = sub.matches.getMany([]const u8, clap.external_id);
        harness.print(a, out, "Calling out to {s} with {s}\n", .{ sub.name, harness.list(a, args) });
    }
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
    harness.print(a, out, "Diffing {s}..{s} {s} (color={s})\n", .{
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
        harness.print(a, out, "Applying {s}\n", .{harness.optOr(sm.getOne([]const u8, "STASH"), "(none)")});
    } else if (std.mem.eql(u8, name, "pop")) {
        harness.print(a, out, "Popping {s}\n", .{harness.optOr(sm.getOne([]const u8, "STASH"), "(none)")});
    } else {
        harness.print(a, out, "Pushing {s}\n", .{harness.optOr(sm.getOne([]const u8, "message"), "(none)")});
    }
}

pub fn main(init: std.process.Init) !void {
    try harness.execMain(init, run);
}
