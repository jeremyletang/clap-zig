//! Ported from clap's tests/builder/subcommands.rs — subcommand dispatch, args vs
//! subcommands with the same name, positional-then-subcommand, `--` then a
//! subcommand-like value, and option values that look like subcommand names.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/subcommands.rs

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

fn sub(a: std.mem.Allocator) Command {
    return Command.init(a, "test")
        .subcommand(Command.init(a, "some").arg(Arg.new("test").short('t').long("test").action(.set)))
        .arg(Arg.new("other").long("other"));
}

test "subcommand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = sub(a);
    const m = run(a, &cmd, &.{ "some", "--test", "testing" }).matches;
    try testing.expectEqualStrings("some", m.subcommand().?.name);
    const sm = m.subcommand().?.matches;
    try testing.expect(sm.contains("test"));
    try testing.expectEqualStrings("testing", sm.getOne([]const u8, "test").?);
}

test "subcommand_multiple" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .subcommand(Command.init(a, "some").arg(Arg.new("test").short('t').long("test").action(.set)))
        .subcommand(Command.init(a, "add").arg(Arg.new("roster").short('r')))
        .arg(Arg.new("other").long("other"));
    const m = run(a, &cmd, &.{ "some", "--test", "testing" }).matches;
    try testing.expectEqualStrings("some", m.subcommand().?.name);
    try testing.expectEqualStrings("testing", m.subcommand().?.matches.getOne([]const u8, "test").?);
}

test "subcommand_none_given" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = sub(a);
    try testing.expect(run(a, &cmd, &.{}).matches.subcommand() == null);
}

test "subcommand_not_recognized" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "fake")
        .subcommand(Command.init(a, "sub"))
        .disableHelpSubcommand(true)
        .inferSubcommands(true);
    try testing.expectEqualStrings(
        "error: unrecognized subcommand 'help'\n\n" ++
            "Usage: fake [COMMAND]\n\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, run(a, &cmd, &.{"help"}).err),
    );
}

test "subcommand_after_argument" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog").arg(Arg.new("some_text")).subcommand(Command.init(a, "test"));
    const m = run(a, &cmd, &.{ "teat", "test" }).matches;
    try testing.expectEqualStrings("teat", m.getOne([]const u8, "some_text").?);
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

test "subcommand_after_argument_looks_like_help" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog").arg(Arg.new("some_text")).subcommand(Command.init(a, "test"));
    const m = run(a, &cmd, &.{ "helt", "test" }).matches;
    try testing.expectEqualStrings("helt", m.getOne([]const u8, "some_text").?);
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

test "issue_2494_subcommand_is_present" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const make = struct {
        fn f(al: std.mem.Allocator) Command {
            return Command.init(al, "opt")
                .arg(Arg.new("global").long("global").action(.set_true))
                .subcommand(Command.init(al, "global"));
        }
    }.f;
    var c1 = make(a);
    const m1 = run(a, &c1, &.{ "--global", "global" }).matches;
    try testing.expectEqualStrings("global", m1.subcommand().?.name);
    try testing.expect(m1.getFlag("global"));

    var c2 = make(a);
    const m2 = run(a, &c2, &.{"--global"}).matches;
    try testing.expect(m2.subcommand() == null);
    try testing.expect(m2.getFlag("global"));

    var c3 = make(a);
    const m3 = run(a, &c3, &.{"global"}).matches;
    try testing.expectEqualStrings("global", m3.subcommand().?.name);
    try testing.expect(!m3.getFlag("global"));
}

test "issue_1031_args_with_same_name" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("ui-path").long("ui-path").action(.set).required(true))
        .subcommand(Command.init(a, "signer"));
    try testing.expectEqualStrings("signer", run(a, &cmd, &.{ "--ui-path", "signer" }).matches.getOne([]const u8, "ui-path").?);
}

test "issue_1031_args_with_same_name_no_more_vals" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("ui-path").long("ui-path").action(.set).required(true))
        .subcommand(Command.init(a, "signer"));
    const m = run(a, &cmd, &.{ "--ui-path", "value", "signer" }).matches;
    try testing.expectEqualStrings("value", m.getOne([]const u8, "ui-path").?);
    try testing.expectEqualStrings("signer", m.subcommand().?.name);
}

test "issue_1722_not_emit_error_when_arg_follows_similar_to_a_subcommand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog").subcommand(Command.init(a, "subcommand")).arg(Arg.new("argument"));
    const m = run(a, &cmd, &.{ "--", "subcommand" }).matches;
    try testing.expectEqualStrings("subcommand", m.getOne([]const u8, "argument").?);
}

test "issue_1161_multiple_hyphen_hyphen" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog")
        .arg(Arg.new("eff").short('f').action(.set_true))
        .arg(Arg.new("pea").short('p').action(.set))
        .arg(Arg.new("slop").action(.set).numArgs(range.atLeast(1)).last(true));
    const m = run(a, &cmd, &.{ "-p=bob", "--", "sloppy", "slop", "-a", "--", "subprogram", "position", "args" }).matches;
    const slop = m.getMany([]const u8, "slop").?;
    const expected = [_][]const u8{ "sloppy", "slop", "-a", "--", "subprogram", "position", "args" };
    try testing.expectEqual(expected.len, slop.len);
    for (expected, slop) |e, g| try testing.expectEqualStrings(e, g);
}
