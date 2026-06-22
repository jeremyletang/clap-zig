//! Ported subset of clap's tests/builder/conflicts.rs — `conflicts_with` /
//! `conflicts_with_all` / `exclusive` mutual exclusion (the arg-arg cases; the
//! group-conflict cases depend on group/arg cross-conflicts not yet wired).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/conflicts.rs

const std = @import("std");
const clap = @import("clap");
const fixture = @import("complex_app.zig");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn complexErr(a: std.mem.Allocator, argv: []const []const u8) []const u8 {
    var cmd = fixture.complexApp(a);
    cmd.buildTree();
    const o = clap.getMatches(a, &cmd, argv);
    return clap.renderError(a, o.err);
}

test "flag_conflict" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flag_conflict")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true).conflictsWith(&.{"other"}))
        .arg(Arg.fromUsage("-o --other", "some flag").action(.set_true));
    try testing.expectEqual(clap.ErrorKind.argument_conflict, run(a, &cmd, &.{ "-f", "-o" }).err.kind);
}

test "flag_conflict_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flag_conflict")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true).conflictsWith(&.{"other"}))
        .arg(Arg.fromUsage("-o --other", "some flag").action(.set_true));
    try testing.expectEqual(clap.ErrorKind.argument_conflict, run(a, &cmd, &.{ "-o", "-f" }).err.kind);
}

test "flag_conflict_with_all" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flag_conflict")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true).conflictsWith(&.{"other"}))
        .arg(Arg.fromUsage("-o --other", "some flag").action(.set_true));
    try testing.expectEqual(clap.ErrorKind.argument_conflict, run(a, &cmd, &.{ "-o", "-f" }).err.kind);
}

test "exclusive_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var ok = Command.init(a, "flag_conflict")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true).exclusive(true))
        .arg(Arg.fromUsage("-o --other", "some flag").action(.set_true));
    try testing.expect(run(a, &ok, &.{"-f"}) == .matches);

    var bad = Command.init(a, "flag_conflict")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true).exclusive(true))
        .arg(Arg.fromUsage("-o --other", "some flag").action(.set_true));
    try testing.expectEqual(clap.ErrorKind.argument_conflict, run(a, &bad, &.{ "-o", "-f" }).err.kind);
}

test "exclusive_option" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flag_conflict")
        .arg(Arg.fromUsage("-f --flag <VALUE>", "some flag").exclusive(true))
        .arg(Arg.fromUsage("-o --other <VALUE>", "some flag"));
    try testing.expectEqual(clap.ErrorKind.argument_conflict, run(a, &cmd, &.{ "-o=val1", "-f=val2" }).err.kind);
}

test "not_exclusive_with_defaults" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flag_conflict")
        .arg(Arg.fromUsage("-f --flag <VALUE>", "some flag").exclusive(true))
        .arg(Arg.fromUsage("-o --other <VALUE>", "some flag").required(false).defaultValue("val1"));
    try testing.expect(run(a, &cmd, &.{"-f=val2"}) == .matches);
}

test "default_doesnt_activate_exclusive" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flag_conflict")
        .arg(Arg.fromUsage("-f --flag <VALUE>", "some flag").exclusive(true).defaultValue("val2"))
        .arg(Arg.fromUsage("-o --other <VALUE>", "some flag").defaultValue("val1"));
    try testing.expect(run(a, &cmd, &.{}) == .matches);
}

test "conflict_with_unused_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "conflict")
        .arg(Arg.fromUsage("-o --opt <opt>", "some opt").defaultValue("default"))
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true).conflictsWith(&.{"opt"}));
    const m = run(a, &cmd, &.{"-f"}).matches;
    try testing.expectEqualStrings("default", m.getOne([]const u8, "opt").?);
    try testing.expect(m.getFlag("flag"));
}

test "conflicts_with_alongside_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "conflict")
        .arg(Arg.fromUsage("-o --opt <opt>", "some opt").defaultValue("default").conflictsWith(&.{"flag"}))
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true));
    const m = run(a, &cmd, &.{"-f"}).matches;
    try testing.expectEqualStrings("default", m.getOne([]const u8, "opt").?);
    try testing.expect(m.getFlag("flag"));
}

test "two_conflicting_arguments" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "two_conflicting_arguments")
        .arg(Arg.new("develop").long("develop").action(.set_true).conflictsWith(&.{"production"}))
        .arg(Arg.new("production").long("production").action(.set_true).conflictsWith(&.{"develop"}));
    const o = run(a, &cmd, &.{ "--develop", "--production" });
    try testing.expectEqual(clap.ErrorKind.argument_conflict, o.err.kind);
    const text = clap.renderError(a, o.err);
    try testing.expect(std.mem.indexOf(u8, text, "the argument '--develop' cannot be used with '--production'") != null);
}

test "three_conflicting_arguments" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "three_conflicting_arguments")
        .arg(Arg.new("one").long("one").action(.set_true).conflictsWith(&.{ "two", "three" }))
        .arg(Arg.new("two").long("two").action(.set_true).conflictsWith(&.{ "one", "three" }))
        .arg(Arg.new("three").long("three").action(.set_true).conflictsWith(&.{ "one", "two" }));
    const o = run(a, &cmd, &.{ "--one", "--two", "--three" });
    try testing.expectEqual(clap.ErrorKind.argument_conflict, o.err.kind);
    const text = clap.renderError(a, o.err);
    try testing.expect(std.mem.indexOf(u8, text, "the argument '--one' cannot be used with:") != null);
}

test "conflict_output_three_conflicting" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "three_conflicting_arguments")
        .arg(Arg.new("one").long("one").action(.set_true).conflictsWith(&.{ "two", "three" }))
        .arg(Arg.new("two").long("two").action(.set_true).conflictsWith(&.{ "one", "three" }))
        .arg(Arg.new("three").long("three").action(.set_true).conflictsWith(&.{ "one", "two" }));
    const o = run(a, &cmd, &.{ "--one", "--two", "--three" });
    try testing.expectEqualStrings(
        "error: the argument '--one' cannot be used with:\n" ++
            "  --two\n" ++
            "  --three\n\n" ++
            "Usage: three_conflicting_arguments --one\n\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, o.err),
    );
}

test "conflict_output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectEqualStrings(
        "error: the argument '--flag...' cannot be used with '-F'\n\n" ++
            "Usage: clap-test --flag... --long-option-2 <option2> <positional> <positional2> [positional3]...\n\n" ++
            "For more information, try '--help'.\n",
        complexErr(a, &.{ "val1", "fa", "--flag", "--long-option-2", "val2", "-F" }),
    );
}

test "conflict_output_rev" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectEqualStrings(
        "error: the argument '-F' cannot be used with '--flag...'\n\n" ++
            "Usage: clap-test -F --long-option-2 <option2> <positional> <positional2> [positional3]...\n\n" ++
            "For more information, try '--help'.\n",
        complexErr(a, &.{ "val1", "fa", "-F", "--long-option-2", "val2", "--flag" }),
    );
}

test "conflict_output_with_required" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectEqualStrings(
        "error: the argument '--flag...' cannot be used with '-F'\n\n" ++
            "Usage: clap-test --flag... --long-option-2 <option2> <positional> <positional2> [positional3]...\n\n" ++
            "For more information, try '--help'.\n",
        complexErr(a, &.{ "val1", "--flag", "--long-option-2", "val2", "-F" }),
    );
}

test "conflict_output_rev_with_required" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectEqualStrings(
        "error: the argument '-F' cannot be used with '--flag...'\n\n" ++
            "Usage: clap-test -F --long-option-2 <option2> <positional> <positional2> [positional3]...\n\n" ++
            "For more information, try '--help'.\n",
        complexErr(a, &.{ "val1", "-F", "--long-option-2", "val2", "--flag" }),
    );
}

test "conflict_output_repeat" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectEqualStrings(
        "error: the argument '-F' cannot be used multiple times\n\n" ++
            "Usage: clap-test [OPTIONS] [positional] [positional2] [positional3]... [COMMAND]\n\n" ++
            "For more information, try '--help'.\n",
        complexErr(a, &.{ "-F", "-F" }),
    );
}
