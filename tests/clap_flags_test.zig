//! Ported subset of clap's tests/builder/flags.rs (implemented-feature cases).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/flags.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

test "flag_using_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flag")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .arg(Arg.fromUsage("-c --color", "some other flag").action(.set_true));
    const m = run(a, &cmd, &.{ "-f", "-c" }).matches;
    try testing.expect(m.getFlag("flag"));
    try testing.expect(m.getFlag("color"));
}

test "flag_using_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flag")
        .arg(Arg.fromUsage("--flag", "some flag").action(.set_true))
        .arg(Arg.fromUsage("--color", "some other flag").action(.set_true));
    const m = run(a, &cmd, &.{ "--flag", "--color" }).matches;
    try testing.expect(m.getFlag("flag"));
    try testing.expect(m.getFlag("color"));
}

test "flag_using_mixed" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "flag")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .arg(Arg.fromUsage("-c --color", "some other flag").action(.set_true));
    const m1 = run(a, &c1, &.{ "-f", "--color" }).matches;
    try testing.expect(m1.getFlag("flag") and m1.getFlag("color"));
    var c2 = Command.init(a, "flag")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .arg(Arg.fromUsage("-c --color", "some other flag").action(.set_true));
    const m2 = run(a, &c2, &.{ "--flag", "-c" }).matches;
    try testing.expect(m2.getFlag("flag") and m2.getFlag("color"));
}

test "multiple_flags_in_single (-fcd)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "multe_flags")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .arg(Arg.fromUsage("-c --color", "some other flag").action(.set_true))
        .arg(Arg.fromUsage("-d --debug", "another other flag").action(.set_true));
    const m = run(a, &cmd, &.{"-fcd"}).matches;
    try testing.expect(m.getFlag("flag"));
    try testing.expect(m.getFlag("color"));
    try testing.expect(m.getFlag("debug"));
}

test "flag_using_long_with_literals (--rainbow=false -> TooManyValues)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flag")
        .arg(Arg.new("rainbow").long("rainbow").action(.set_true));
    const o = run(a, &cmd, &.{"--rainbow=false"});
    try testing.expectEqual(clap.ErrorKind.too_many_values, o.err.kind);
}

test "unexpected_value_error (--a-flag=foo)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "mycat")
        .arg(Arg.new("filename"))
        .arg(Arg.new("a-flag").long("a-flag").action(.set_true));
    const o = run(a, &cmd, &.{"--a-flag=foo"});
    try testing.expectEqualStrings(
        "error: unexpected value 'foo' for '--a-flag' found; no more were expected\n" ++
            "\n" ++
            "Usage: mycat --a-flag [filename]\n" ++
            "\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, o.err),
    );
}
