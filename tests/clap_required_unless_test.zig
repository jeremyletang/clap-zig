//! Ported subset of clap's tests/builder/require.rs — `required_unless_present`
//! / `_any` / `_all` (an arg becomes required unless the named arg(s) appear).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/require.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

test "required_unless_present" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlesstest")
        .arg(Arg.new("cfg").requiredUnlessPresentAny(&.{"dbg"}).action(.set).long("config"))
        .arg(Arg.new("dbg").long("debug").action(.set_true));
    const o = run(a, &cmd, &.{"--debug"});
    try testing.expect(o == .matches);
    try testing.expect(o.matches.getFlag("dbg"));
    try testing.expect(!o.matches.contains("cfg"));
}

test "required_unless_present_err" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlesstest")
        .arg(Arg.new("cfg").requiredUnlessPresentAny(&.{"dbg"}).action(.set).long("config"))
        .arg(Arg.new("dbg").long("debug").action(.set_true));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{}).err.kind);
}

test "required_unless_present_with_optional_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlesstest")
        .arg(Arg.new("opt").long("opt").numArgs(clap.ValueRange.between(0, 1)))
        .arg(Arg.new("cfg").requiredUnlessPresentAny(&.{"dbg"}).action(.set).long("config"))
        .arg(Arg.new("dbg").long("debug").action(.set_true));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{"--opt"}).err.kind);
}

test "required_unless_present_all" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessall")
        .arg(Arg.new("cfg").requiredUnlessPresentAll(&.{ "dbg", "infile" }).action(.set).long("config"))
        .arg(Arg.new("dbg").long("debug").action(.set_true))
        .arg(Arg.new("infile").short('i').action(.set));
    const o = run(a, &cmd, &.{ "--debug", "-i", "file" });
    try testing.expect(o == .matches);
    try testing.expect(o.matches.getFlag("dbg"));
    try testing.expect(o.matches.contains("infile"));
    try testing.expect(!o.matches.contains("cfg"));
}

test "required_unless_all_err" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessall")
        .arg(Arg.new("cfg").requiredUnlessPresentAll(&.{ "dbg", "infile" }).action(.set).long("config"))
        .arg(Arg.new("dbg").long("debug").action(.set_true))
        .arg(Arg.new("infile").short('i').action(.set));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{"--debug"}).err.kind);
}

test "required_unless_present_any" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("cfg").requiredUnlessPresentAny(&.{ "dbg", "infile" }).action(.set).long("config"))
        .arg(Arg.new("dbg").long("debug").action(.set_true))
        .arg(Arg.new("infile").short('i').action(.set));
    const o = run(a, &cmd, &.{"--debug"});
    try testing.expect(o == .matches);
    try testing.expect(o.matches.getFlag("dbg"));
    try testing.expect(!o.matches.contains("cfg"));
}

test "required_unless_any_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("cfg").requiredUnlessPresentAny(&.{ "dbg", "infile" }).action(.set).long("config"))
        .arg(Arg.new("dbg").long("debug").action(.set_true))
        .arg(Arg.new("infile").short('i').action(.set));
    const o = run(a, &cmd, &.{ "-i", "file" });
    try testing.expect(o == .matches);
    try testing.expect(o.matches.contains("infile"));
    try testing.expect(!o.matches.contains("cfg"));
}

test "required_unless_any_works_with_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("a").conflictsWith(&.{"b"}).short('a').action(.set_true))
        .arg(Arg.new("b").short('b').action(.set_true))
        .arg(Arg.new("x").short('x').action(.set_true).requiredUnlessPresentAny(&.{ "a", "b" }));
    try testing.expect(run(a, &cmd, &.{"-a"}) == .matches);
}

test "required_unless_any_works_with_short_err" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("a").conflictsWith(&.{"b"}).short('a').action(.set_true))
        .arg(Arg.new("b").short('b').action(.set_true))
        .arg(Arg.new("x").short('x').action(.set_true).requiredUnlessPresentAny(&.{ "a", "b" }));
    try testing.expect(run(a, &cmd, &.{}) == .err);
}

test "required_unless_any_works_without" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("a").conflictsWith(&.{"b"}).short('a').action(.set_true))
        .arg(Arg.new("b").short('b').action(.set_true))
        .arg(Arg.new("x").requiredUnlessPresentAny(&.{ "a", "b" }));
    try testing.expect(run(a, &cmd, &.{"-a"}) == .matches);
}

test "required_unless_any_works_with_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("a").conflictsWith(&.{"b"}).short('a').action(.set_true))
        .arg(Arg.new("b").short('b').action(.set_true))
        .arg(Arg.new("x").long("x_is_the_option").action(.set_true).requiredUnlessPresentAny(&.{ "a", "b" }));
    try testing.expect(run(a, &cmd, &.{"-a"}) == .matches);
}

test "required_unless_any_1" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("cfg").requiredUnlessPresentAny(&.{ "dbg", "infile" }).action(.set).long("config"))
        .arg(Arg.new("dbg").long("debug").action(.set_true))
        .arg(Arg.new("infile").short('i').action(.set));
    const o = run(a, &cmd, &.{"--debug"});
    try testing.expect(o == .matches);
    try testing.expect(!o.matches.contains("infile"));
    try testing.expect(!o.matches.contains("cfg"));
    try testing.expect(o.matches.getFlag("dbg"));
}

test "required_unless_any_err" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("cfg").requiredUnlessPresentAny(&.{ "dbg", "infile" }).action(.set).long("config"))
        .arg(Arg.new("dbg").long("debug").action(.set_true))
        .arg(Arg.new("infile").short('i').action(.set));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{}).err.kind);
}

test "required_unless_all_with_any" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const build = struct {
        fn f(al: std.mem.Allocator) Command {
            return Command.init(al, "prog")
                .arg(Arg.new("foo").long("foo").action(.set_true))
                .arg(Arg.new("bar").long("bar").action(.set_true))
                .arg(Arg.new("baz").long("baz").action(.set_true))
                .arg(Arg.new("flag").long("flag").action(.set_true)
                .requiredUnlessPresentAny(&.{"foo"})
                .requiredUnlessPresentAll(&.{ "bar", "baz" }));
        }
    }.f;

    var c1 = build(a);
    try testing.expect(run(a, &c1, &.{}) == .err);

    var c2 = build(a);
    const o2 = run(a, &c2, &.{"--foo"});
    try testing.expect(o2 == .matches);
    try testing.expect(!o2.matches.getFlag("flag"));

    var c3 = build(a);
    const o3 = run(a, &c3, &.{ "--bar", "--baz" });
    try testing.expect(o3 == .matches);
    try testing.expect(!o3.matches.getFlag("flag"));

    var c4 = build(a);
    try testing.expect(run(a, &c4, &.{"--bar"}) == .err);
}

test "multiple_required_unless_usage_printing" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.new("a").long("a").action(.set).requiredUnlessPresentAny(&.{"b"}).conflictsWith(&.{"b"}))
        .arg(Arg.new("b").long("b").action(.set).requiredUnlessPresentAny(&.{"a"}).conflictsWith(&.{"a"}))
        .arg(Arg.new("c").long("c").action(.set).requiredUnlessPresentAny(&.{"d"}).conflictsWith(&.{"d"}))
        .arg(Arg.new("d").long("d").action(.set).requiredUnlessPresentAny(&.{"c"}).conflictsWith(&.{"c"}));
    const o = run(a, &cmd, &.{ "--c", "asd" });
    try testing.expectEqualStrings(
        "error: the following required arguments were not provided:\n" ++
            "  --a <a>\n  --b <b>\n\n" ++
            "Usage: test --c <c> --a <a> --b <b>\n\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, o.err),
    );
}
