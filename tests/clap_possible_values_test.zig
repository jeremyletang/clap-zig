//! Ported subset of clap's tests/builder/possible_values.rs (implemented-feature cases).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/possible_values.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

test "possible_values_of_positional (+ fail)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var ok = Command.init(a, "pv").arg(Arg.new("positional").valueParser(&.{"test123"}));
    try testing.expectEqualStrings("test123", run(a, &ok, &.{"test123"}).matches.getOne([]const u8, "positional").?);
    var bad = Command.init(a, "pv").arg(Arg.new("positional").valueParser(&.{"test123"}));
    try testing.expectEqual(clap.ErrorKind.invalid_value, run(a, &bad, &.{"notest"}).err.kind);
}

test "possible_value_arg_value (PossibleValue with help)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "pv")
        .arg(Arg.new("arg_value").possibleValues(&.{.{ .name = "test123", .help = "It's just a test" }}));
    try testing.expectEqualStrings("test123", run(a, &cmd, &.{"test123"}).matches.getOne([]const u8, "arg_value").?);
}

test "possible_values_of_positional_multiple (+ fail)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var ok = Command.init(a, "pv")
        .arg(Arg.new("positional").action(.set).valueParser(&.{ "test123", "test321" }).numArgs(clap.ValueRange.atLeast(1)));
    const p = run(a, &ok, &.{ "test123", "test321" }).matches.getMany([]const u8, "positional").?;
    try testing.expectEqual(@as(usize, 2), p.len);
    var bad = Command.init(a, "pv")
        .arg(Arg.new("positional").action(.set).valueParser(&.{ "test123", "test321" }).numArgs(clap.ValueRange.atLeast(1)));
    try testing.expectEqual(clap.ErrorKind.invalid_value, run(a, &bad, &.{ "test123", "notest" }).err.kind);
}

test "possible_values_of_option (+ fail)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var ok = Command.init(a, "pv")
        .arg(Arg.new("option").short('o').long("option").action(.set).valueParser(&.{"test123"}));
    try testing.expectEqualStrings("test123", run(a, &ok, &.{ "--option", "test123" }).matches.getOne([]const u8, "option").?);
    var bad = Command.init(a, "pv")
        .arg(Arg.new("option").short('o').long("option").action(.set).valueParser(&.{"test123"}));
    try testing.expectEqual(clap.ErrorKind.invalid_value, run(a, &bad, &.{ "--option", "notest" }).err.kind);
}

test "possible_values_of_option_multiple via append (+ fail)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var ok = Command.init(a, "pv")
        .arg(Arg.new("option").short('o').long("option").action(.append).valueParser(&.{ "test123", "test321" }));
    const m = run(a, &ok, &.{ "--option", "test123", "--option", "test321" }).matches.getMany([]const u8, "option").?;
    try testing.expectEqual(@as(usize, 2), m.len);
    try testing.expectEqualStrings("test321", m[1]);
    var bad = Command.init(a, "pv")
        .arg(Arg.new("option").short('o').long("option").action(.append).valueParser(&.{ "test123", "test321" }));
    try testing.expectEqual(clap.ErrorKind.invalid_value, run(a, &bad, &.{ "--option", "test123", "--option", "notest" }).err.kind);
}

test "ignore_case_fail (case-sensitive by default)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "pv")
        .arg(Arg.new("option").short('o').long("option").action(.set).valueParser(&.{ "test123", "test321" }));
    try testing.expectEqual(clap.ErrorKind.invalid_value, run(a, &cmd, &.{ "--option", "TeSt123" }).err.kind);
}
