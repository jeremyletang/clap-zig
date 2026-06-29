//! Ported from clap's tests/builder/app_settings.rs — the `aaos_*` cluster:
//! args_override_self combined with overrides_with, append, and value_delimiter.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/app_settings.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const range = clap.ValueRange;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn expectMany(m: *const clap.ArgMatches, id: []const u8, expected: []const []const u8) !void {
    const v = m.getMany([]const u8, id).?;
    try testing.expectEqual(expected.len, v.len);
    for (expected, v) |e, g| try testing.expectEqualStrings(e, g);
}

test "aaos_opts_w_other_overrides" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix").argsOverrideSelf(true)
        .arg(Arg.new("opt").long("opt").action(.set))
        .arg(Arg.new("other").long("other").action(.set).overridesWith(&.{"opt"}));
    const m = run(a, &cmd, &.{ "--opt=some", "--other=test", "--opt=other" }).matches;
    try testing.expect(m.contains("opt"));
    try testing.expect(!m.contains("other"));
    try testing.expectEqualStrings("other", m.getOne([]const u8, "opt").?);
}

test "aaos_opts_w_other_overrides_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix").argsOverrideSelf(true)
        .arg(Arg.new("opt").long("opt").action(.set).overridesWith(&.{"other"}))
        .arg(Arg.new("other").long("other").action(.set));
    const m = run(a, &cmd, &.{ "--opt=some", "--other=test", "--opt=other" }).matches;
    try testing.expect(m.contains("opt"));
    try testing.expect(!m.contains("other"));
    try testing.expectEqualStrings("other", m.getOne([]const u8, "opt").?);
}

test "aaos_opts_w_other_overrides_rev" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix").argsOverrideSelf(true)
        .arg(Arg.new("opt").long("opt").action(.set).required(true))
        .arg(Arg.new("other").long("other").action(.set).required(true).overridesWith(&.{"opt"}));
    const m = run(a, &cmd, &.{ "--opt=some", "--opt=other", "--other=val" }).matches;
    try testing.expect(!m.contains("opt"));
    try testing.expect(m.contains("other"));
    try testing.expectEqualStrings("val", m.getOne([]const u8, "other").?);
}

test "aaos_opts_w_other_overrides_rev_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix").argsOverrideSelf(true)
        .arg(Arg.new("opt").long("opt").action(.set).required(true).overridesWith(&.{"other"}))
        .arg(Arg.new("other").long("other").action(.set).required(true));
    const m = run(a, &cmd, &.{ "--opt=some", "--opt=other", "--other=val" }).matches;
    try testing.expect(!m.contains("opt"));
    try testing.expect(m.contains("other"));
    try testing.expectEqualStrings("val", m.getOne([]const u8, "other").?);
}

test "aaos_opts_w_override_as_conflict_1" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.new("opt").long("opt").action(.set).required(true).overridesWith(&.{"other"}))
        .arg(Arg.new("other").long("other").action(.set).required(true));
    const m = run(a, &cmd, &.{"--opt=some"}).matches;
    try testing.expect(m.contains("opt"));
    try testing.expect(!m.contains("other"));
    try testing.expectEqualStrings("some", m.getOne([]const u8, "opt").?);
}

test "aaos_opts_w_override_as_conflict_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.new("opt").long("opt").action(.set).required(true).overridesWith(&.{"other"}))
        .arg(Arg.new("other").long("other").action(.set).required(true));
    const m = run(a, &cmd, &.{"--other=some"}).matches;
    try testing.expect(!m.contains("opt"));
    try testing.expect(m.contains("other"));
    try testing.expectEqualStrings("some", m.getOne([]const u8, "other").?);
}

test "aaos_opts_mult" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.new("opt").long("opt").action(.append).numArgs(range.atLeast(1)));
    const m = run(a, &cmd, &.{ "--opt", "first", "overrides", "--opt", "some", "other", "val" }).matches;
    try expectMany(m, "opt", &.{ "first", "overrides", "some", "other", "val" });
}

test "aaos_opts_mult_req_delims" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix")
        .arg(Arg.new("opt").long("opt").action(.append).valueDelimiter(','));
    const m = run(a, &cmd, &.{ "--opt=some", "--opt=other", "--opt=one,two" }).matches;
    try expectMany(m, "opt", &.{ "some", "other", "one", "two" });
}

test "aaos_pos_mult" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix").arg(Arg.new("val").action(.set).numArgs(range.atLeast(1)));
    const m = run(a, &cmd, &.{ "some", "other", "value" }).matches;
    try expectMany(m, "val", &.{ "some", "other", "value" });
}

test "aaos_option_use_delim_false" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "posix").argsOverrideSelf(true)
        .arg(Arg.new("opt").long("opt").action(.set).required(true));
    const m = run(a, &cmd, &.{ "--opt=some,other", "--opt=one,two" }).matches;
    try expectMany(m, "opt", &.{"one,two"});
}
