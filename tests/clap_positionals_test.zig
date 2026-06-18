//! Ported subset of clap's tests/builder/positionals.rs (implemented-feature cases).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/positionals.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn usageOf(a: std.mem.Allocator, cmd: *Command) []const u8 {
    cmd.buildTree();
    return clap.renderUsage(a, cmd);
}

test "only_pos_follow (-- -f)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "onlypos")
        .arg(Arg.fromUsage("f: -f [flag]", "some opt"))
        .arg(Arg.fromUsage("[arg]", "some arg"));
    const m = run(a, &cmd, &.{ "--", "-f" }).matches;
    try testing.expectEqualStrings("-f", m.getOne([]const u8, "arg").?);
    try testing.expect(!m.isPresent("f"));
}

test "positional with flag, both orders" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "positional")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .arg(Arg.new("positional"));
    const m1 = run(a, &c1, &.{ "-f", "test" }).matches;
    try testing.expect(m1.getFlag("flag"));
    try testing.expectEqualStrings("test", m1.getOne([]const u8, "positional").?);
    var c2 = Command.init(a, "positional")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .arg(Arg.new("positional"));
    const m2 = run(a, &c2, &.{ "test", "--flag" }).matches;
    try testing.expect(m2.getFlag("flag"));
    try testing.expectEqualStrings("test", m2.getOne([]const u8, "positional").?);
}

test "lots_o_vals (variadic positional, 297)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "opts").arg(Arg.fromUsage("<opt>...", "some pos"));
    var args: std.ArrayListUnmanaged([]const u8) = .empty;
    for (0..297) |_| args.append(a, "some") catch unreachable;
    const m = run(a, &cmd, args.items).matches;
    try testing.expectEqual(@as(usize, 297), m.getMany([]const u8, "opt").?.len);
}

test "positional_multiple (num_args 1..)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "positional_multiple")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .arg(Arg.new("positional").action(.set).numArgs(clap.ValueRange.atLeast(1)));
    const m = run(a, &cmd, &.{ "-f", "test1", "test2", "test3" }).matches;
    try testing.expect(m.getFlag("flag"));
    const p = m.getMany([]const u8, "positional").?;
    try testing.expectEqual(@as(usize, 3), p.len);
    try testing.expectEqualStrings("test3", p[2]);
}

test "positional_multiple_3 (values before flag)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "positional_multiple")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .arg(Arg.new("positional").action(.set).numArgs(clap.ValueRange.atLeast(1)));
    const m = run(a, &cmd, &.{ "test1", "test2", "test3", "--flag" }).matches;
    try testing.expect(m.getFlag("flag"));
    try testing.expectEqual(@as(usize, 3), m.getMany([]const u8, "positional").?.len);
}

test "positional_multiple_2 (too many for single positional)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "positional_multiple")
        .arg(Arg.fromUsage("-f --flag", "some flag"))
        .arg(Arg.new("positional"));
    const o = run(a, &cmd, &.{ "-f", "test1", "test2", "test3" });
    try testing.expectEqual(clap.ErrorKind.unknown_argument, o.err.kind);
}

test "positional_possible_values" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ppv")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .arg(Arg.new("positional").valueParser(&.{"test123"}));
    const m = run(a, &cmd, &.{ "-f", "test123" }).matches;
    try testing.expectEqualStrings("test123", m.getOne([]const u8, "positional").?);
}

test "create_positional / hyphen value does not error" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "test").arg(Arg.new("test"));
    try testing.expect(run(a, &c1, &.{}) == .matches);
    var c2 = Command.init(a, "test").arg(Arg.new("dummy"));
    try testing.expect(run(a, &c2, &.{"-"}) == .matches);
}

test "missing_required_2 (one of two required positionals)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.fromUsage("<FILE1>", "some file"))
        .arg(Arg.fromUsage("<FILE2>", "some file"));
    const o = run(a, &cmd, &.{"file"});
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, o.err.kind);
}

test "last_positional (-- arg fills last)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.fromUsage("<TARGET>", "some target"))
        .arg(Arg.fromUsage("[CORPUS]", "some corpus"))
        .arg(Arg.fromUsage("[ARGS]...", "some file").last(true));
    const m = run(a, &cmd, &.{ "tgt", "--", "arg" }).matches;
    const args = m.getMany([]const u8, "ARGS").?;
    try testing.expectEqual(@as(usize, 1), args.len);
    try testing.expectEqualStrings("arg", args[0]);
}

test "last_positional_no_double_dash errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.fromUsage("<TARGET>", "some target"))
        .arg(Arg.fromUsage("[CORPUS]", "some corpus"))
        .arg(Arg.fromUsage("[ARGS]...", "some file").last(true));
    const o = run(a, &cmd, &.{ "tgt", "crp", "arg" });
    try testing.expectEqual(clap.ErrorKind.unknown_argument, o.err.kind);
}

test "last_positional_second_to_last_mult" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.fromUsage("<TARGET>", "some target"))
        .arg(Arg.fromUsage("[CORPUS]...", "some corpus"))
        .arg(Arg.fromUsage("[ARGS]...", "some file").last(true));
    try testing.expect(run(a, &cmd, &.{ "tgt", "crp1", "crp2", "--", "arg" }) == .matches);
}

test "positional usage strings" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "test").arg(Arg.fromUsage("[FILE]", "some file"));
    try testing.expectEqualStrings("Usage: test [FILE]", usageOf(a, &c1));
    var c2 = Command.init(a, "test").arg(Arg.fromUsage("[FILE]...", "some file"));
    try testing.expectEqualStrings("Usage: test [FILE]...", usageOf(a, &c2));
    var c3 = Command.init(a, "test")
        .arg(Arg.fromUsage("[FILE]", "some file"))
        .arg(Arg.fromUsage("[FILES]...", "some file"));
    try testing.expectEqualStrings("Usage: test [FILE] [FILES]...", usageOf(a, &c3));
    var c4 = Command.init(a, "test")
        .arg(Arg.fromUsage("<FILE>", "some file"))
        .arg(Arg.fromUsage("[FILES]...", "some file"));
    try testing.expectEqualStrings("Usage: test <FILE> [FILES]...", usageOf(a, &c4));
    var c5 = Command.init(a, "test").arg(Arg.fromUsage("<FILE>", "some file"));
    try testing.expectEqualStrings("Usage: test <FILE>", usageOf(a, &c5));
}
