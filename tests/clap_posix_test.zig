//! Ported subset of clap's tests/builder/posix_compatible.rs — `overrides_with`
//! (last-of-pair wins; overrides relax conflicts and required).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/posix_compatible.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

test "flag_overrides_itself" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("--flag", "some flag").action(.set_true).overridesWith(&.{"flag"}));
    const o = run(a, &cmd, &.{ "--flag", "--flag" });
    try testing.expect(o == .matches);
    try testing.expect(o.matches.getFlag("flag"));
}

test "option_overrides_itself" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("--opt <val>", "some option").required(false).overridesWith(&.{"opt"}));
    const o = run(a, &cmd, &.{ "--opt=some", "--opt=other" });
    try testing.expect(o == .matches);
    try testing.expect(o.matches.contains("opt"));
    try testing.expectEqualStrings("other", o.matches.getOne([]const u8, "opt").?);
}

test "posix_compatible_flags_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("--flag", "some flag").overridesWith(&.{"color"}).action(.set_true))
        .arg(Arg.fromUsage("--color", "some other flag").action(.set_true));
    const m = run(a, &cmd, &.{ "--flag", "--color" }).matches;
    try testing.expect(m.getFlag("color"));
    try testing.expect(!m.getFlag("flag"));
}

test "posix_compatible_flags_long_rev" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("--flag", "some flag").overridesWith(&.{"color"}).action(.set_true))
        .arg(Arg.fromUsage("--color", "some other flag").action(.set_true));
    const m = run(a, &cmd, &.{ "--color", "--flag" }).matches;
    try testing.expect(!m.getFlag("color"));
    try testing.expect(m.getFlag("flag"));
}

test "posix_compatible_flags_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("-f --flag", "some flag").overridesWith(&.{"color"}).action(.set_true))
        .arg(Arg.fromUsage("-c --color", "some other flag").action(.set_true));
    const m = run(a, &cmd, &.{ "-f", "-c" }).matches;
    try testing.expect(m.getFlag("color"));
    try testing.expect(!m.getFlag("flag"));
}

test "posix_compatible_flags_short_rev" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("-f --flag", "some flag").overridesWith(&.{"color"}).action(.set_true))
        .arg(Arg.fromUsage("-c --color", "some other flag").action(.set_true));
    const m = run(a, &cmd, &.{ "-c", "-f" }).matches;
    try testing.expect(!m.getFlag("color"));
    try testing.expect(m.getFlag("flag"));
}

test "posix_compatible_opts_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("--flag <flag>", "some flag").overridesWith(&.{"color"}))
        .arg(Arg.fromUsage("--color <color>", "some other flag"));
    const m = run(a, &cmd, &.{ "--flag", "some", "--color", "other" }).matches;
    try testing.expect(m.contains("color"));
    try testing.expectEqualStrings("other", m.getOne([]const u8, "color").?);
    try testing.expect(!m.contains("flag"));
}

test "posix_compatible_opts_long_rev" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("--flag <flag>", "some flag").overridesWith(&.{"color"}))
        .arg(Arg.fromUsage("--color <color>", "some other flag"));
    const m = run(a, &cmd, &.{ "--color", "some", "--flag", "other" }).matches;
    try testing.expect(!m.contains("color"));
    try testing.expect(m.contains("flag"));
    try testing.expectEqualStrings("other", m.getOne([]const u8, "flag").?);
}

test "posix_compatible_opts_long_equals" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("--flag <flag>", "some flag").overridesWith(&.{"color"}))
        .arg(Arg.fromUsage("--color <color>", "some other flag"));
    const m = run(a, &cmd, &.{ "--flag=some", "--color=other" }).matches;
    try testing.expect(m.contains("color"));
    try testing.expectEqualStrings("other", m.getOne([]const u8, "color").?);
    try testing.expect(!m.contains("flag"));
}

test "posix_compatible_opts_long_equals_rev" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("--flag <flag>", "some flag").overridesWith(&.{"color"}))
        .arg(Arg.fromUsage("--color <color>", "some other flag"));
    const m = run(a, &cmd, &.{ "--color=some", "--flag=other" }).matches;
    try testing.expect(!m.contains("color"));
    try testing.expect(m.contains("flag"));
    try testing.expectEqualStrings("other", m.getOne([]const u8, "flag").?);
}

test "posix_compatible_opts_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("f: -f <flag>", "some flag").overridesWith(&.{"c"}))
        .arg(Arg.fromUsage("c: -c <color>", "some other flag"));
    const m = run(a, &cmd, &.{ "-f", "some", "-c", "other" }).matches;
    try testing.expect(m.contains("c"));
    try testing.expectEqualStrings("other", m.getOne([]const u8, "c").?);
    try testing.expect(!m.contains("f"));
}

test "posix_compatible_opts_short_rev" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.fromUsage("f: -f <flag>", "some flag").overridesWith(&.{"c"}))
        .arg(Arg.fromUsage("c: -c <color>", "some other flag"));
    const m = run(a, &cmd, &.{ "-c", "some", "-f", "other" }).matches;
    try testing.expect(!m.contains("c"));
    try testing.expect(m.contains("f"));
    try testing.expectEqualStrings("other", m.getOne([]const u8, "f").?);
}

test "conflict_overridden" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "conflict_overridden")
        .arg(Arg.fromUsage("-f --flag", "some flag").conflictsWith(&.{"debug"}).action(.set_true))
        .arg(Arg.fromUsage("-d --debug", "other flag").action(.set_true))
        .arg(Arg.fromUsage("-c --color", "third flag").overridesWith(&.{"flag"}).action(.set_true));
    const o = run(a, &cmd, &.{ "-f", "-c", "-d" });
    try testing.expect(o == .matches);
    const m = o.matches;
    try testing.expect(m.getFlag("color"));
    try testing.expect(!m.getFlag("flag"));
    try testing.expect(m.getFlag("debug"));
}

test "conflict_overridden_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "conflict_overridden")
        .arg(Arg.fromUsage("-f --flag", "some flag").conflictsWith(&.{"debug"}).action(.set_true))
        .arg(Arg.fromUsage("-d --debug", "other flag").action(.set_true))
        .arg(Arg.fromUsage("-c --color", "third flag").overridesWith(&.{"flag"}).action(.set_true));
    const o = run(a, &cmd, &.{ "-f", "-d", "-c" });
    try testing.expect(o == .matches);
    const m = o.matches;
    try testing.expect(m.getFlag("color"));
    try testing.expect(m.getFlag("debug"));
    try testing.expect(!m.getFlag("flag"));
}

test "conflict_overridden_3" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "conflict_overridden")
        .arg(Arg.fromUsage("-f --flag", "some flag").conflictsWith(&.{"debug"}))
        .arg(Arg.fromUsage("-d --debug", "other flag"))
        .arg(Arg.fromUsage("-c --color", "third flag").overridesWith(&.{"flag"}));
    const o = run(a, &cmd, &.{ "-d", "-c", "-f" });
    try testing.expectEqual(clap.ErrorKind.argument_conflict, o.err.kind);
}

test "conflict_overridden_4" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "conflict_overridden")
        .arg(Arg.fromUsage("-f --flag", "some flag").conflictsWith(&.{"debug"}).action(.set_true))
        .arg(Arg.fromUsage("-d --debug", "other flag").action(.set_true))
        .arg(Arg.fromUsage("-c --color", "third flag").overridesWith(&.{"flag"}).action(.set_true));
    const o = run(a, &cmd, &.{ "-d", "-f", "-c" });
    try testing.expect(o == .matches);
    const m = o.matches;
    try testing.expect(m.getFlag("color"));
    try testing.expect(!m.getFlag("flag"));
    try testing.expect(m.getFlag("debug"));
}

test "pos_required_overridden_by_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "require_overridden")
        .arg(Arg.new("pos").required(true))
        .arg(Arg.fromUsage("-c --color", "some flag").overridesWith(&.{"pos"}));
    const o = run(a, &cmd, &.{ "test", "-c" });
    try testing.expect(o == .matches);
}

test "require_overridden_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "require_overridden")
        .arg(Arg.new("req_pos").required(true))
        .arg(Arg.fromUsage("-c --color", "other flag").overridesWith(&.{"req_pos"}).action(.set_true));
    const o = run(a, &cmd, &.{ "-c", "req_pos" });
    try testing.expect(o == .matches);
    const m = o.matches;
    try testing.expect(!m.getFlag("color"));
    try testing.expect(m.contains("req_pos"));
}

test "require_overridden_3" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "require_overridden")
        .arg(Arg.fromUsage("-f --flag", "some flag").requires("debug").action(.set_true))
        .arg(Arg.fromUsage("-d --debug", "other flag").action(.set_true))
        .arg(Arg.fromUsage("-c --color", "third flag").overridesWith(&.{"flag"}).action(.set_true));
    const o = run(a, &cmd, &.{ "-f", "-c" });
    try testing.expect(o == .matches);
    const m = o.matches;
    try testing.expect(m.getFlag("color"));
    try testing.expect(!m.getFlag("flag"));
    try testing.expect(!m.getFlag("debug"));
}

test "require_overridden_4" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "require_overridden")
        .arg(Arg.fromUsage("-f --flag", "some flag").requires("debug"))
        .arg(Arg.fromUsage("-d --debug", "other flag"))
        .arg(Arg.fromUsage("-c --color", "third flag").overridesWith(&.{"flag"}));
    const o = run(a, &cmd, &.{ "-c", "-f" });
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, o.err.kind);
}

test "incremental_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.fromUsage("--name <NAME>...", "name").required(true))
        .arg(Arg.fromUsage("--no-name", "no name").overridesWith(&.{"name"}).action(.set_true));
    const o = run(a, &cmd, &.{ "--name=ahmed", "--no-name", "--name=ali" });
    try testing.expect(o == .matches);
    const m = o.matches;
    const names = m.getMany([]const u8, "name").?;
    try testing.expectEqual(@as(usize, 1), names.len);
    try testing.expectEqualStrings("ali", names[0]);
    try testing.expect(!m.getFlag("no-name"));
}
