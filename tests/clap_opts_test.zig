//! Ported subset of clap's tests/builder/opts.rs — the cases that exercise
//! features clap-zig implements. Used as a hardening oracle.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/opts.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

test "require_equals: space instead of = fails with NoEquals" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("cfg").long("config").action(.set).requireEquals(true));
    const o = run(a, &cmd, &.{ "--config", "file.conf" });
    try testing.expectEqual(clap.ErrorKind.no_equals, o.err.kind);
}

test "require_equals: = passes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("cfg").long("config").action(.set).requireEquals(true));
    const m = run(a, &cmd, &.{"--config=file.conf"}).matches;
    try testing.expectEqualStrings("file.conf", m.getOne([]const u8, "cfg").?);
}

test "require_equals: empty value passes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("cfg").long("config").action(.set).requireEquals(true));
    try testing.expect(run(a, &cmd, &.{"--config="}) == .matches);
}

test "opts using short, space-separated values" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "opts")
        .arg(Arg.fromUsage("f: -f [flag]", "some flag"))
        .arg(Arg.fromUsage("c: -c [color]", "some other flag"));
    const m = run(a, &cmd, &.{ "-f", "some", "-c", "other" }).matches;
    try testing.expectEqualStrings("some", m.getOne([]const u8, "f").?);
    try testing.expectEqualStrings("other", m.getOne([]const u8, "c").?);
}

test "opts using long, space and equals" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "opts")
        .arg(Arg.fromUsage("--flag [flag]", "some flag"))
        .arg(Arg.fromUsage("--color [color]", "some other flag"));
    const space = run(a, &cmd, &.{ "--flag", "some", "--color", "other" }).matches;
    try testing.expectEqualStrings("some", space.getOne([]const u8, "flag").?);
    var cmd2 = Command.init(a, "opts")
        .arg(Arg.fromUsage("--flag [flag]", "some flag"))
        .arg(Arg.fromUsage("--color [color]", "some other flag"));
    const eq = run(a, &cmd2, &.{ "--flag=some", "--color=other" }).matches;
    try testing.expectEqualStrings("other", eq.getOne([]const u8, "color").?);
}

test "opts using mixed short/long, space and equals" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "opts")
        .arg(Arg.fromUsage("-f --flag [flag]", "some flag"))
        .arg(Arg.fromUsage("-c --color [color]", "some other flag"));
    const m = run(a, &cmd, &.{ "--flag=some", "-c", "other" }).matches;
    try testing.expectEqualStrings("some", m.getOne([]const u8, "flag").?);
    try testing.expectEqualStrings("other", m.getOne([]const u8, "color").?);
}

test "default value overridden by user value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.fromUsage("o: -o [opt]", "some opt").defaultValue("default"));
    const m = run(a, &cmd, &.{ "-o", "value" }).matches;
    try testing.expectEqualStrings("value", m.getOne([]const u8, "o").?);
}

test "stdin char '-' is a value, not a flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "opts").arg(Arg.fromUsage("f: -f [flag]", "some flag"));
    const m = run(a, &cmd, &.{ "-f", "-" }).matches;
    try testing.expectEqualStrings("-", m.getOne([]const u8, "f").?);
}

test "append option with =value plus positional" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "mvae")
        .arg(Arg.fromUsage("o: -o [opt] ...", "some opt"))
        .arg(Arg.fromUsage("[file]", "some file"));
    const m = run(a, &cmd, &.{ "-o=1", "some" }).matches;
    try testing.expectEqualStrings("1", m.getOne([]const u8, "o").?);
    try testing.expectEqualStrings("some", m.getOne([]const u8, "file").?);
}

test "require_equals message shows --config=<cfg>" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("cfg").long("config").action(.set).requireEquals(true));
    const o = run(a, &cmd, &.{ "--config", "file.conf" });
    try testing.expectEqualStrings(
        "error: equal sign is needed when assigning values to '--config=<cfg>'\n" ++
            "\n" ++
            "Usage: prog [OPTIONS]\n" ++
            "\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, o.err),
    );
}
