//! Ported subset of clap's tests/builder/require.rs — `requires` /
//! `requires_if` / `requires_ifs` (the unconditional and value-conditional
//! requirement edges). required_unless_present / required_if_eq are separate.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/require.rs

const std = @import("std");
const clap = @import("clap");
const fixture = @import("complex_app.zig");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const ArgGroup = clap.ArgGroup;
const RequireIf = clap.RequireIf;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn errOf(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Error {
    return run(a, cmd, argv).err;
}

test "flag_required" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flag_required")
        .arg(Arg.fromUsage("-f --flag", "some flag").requires("color"))
        .arg(Arg.fromUsage("-c --color", "third flag"));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, errOf(a, &cmd, &.{"-f"}).kind);
}

test "flag_required_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "flag_required")
        .arg(Arg.fromUsage("-f --flag", "some flag").requires("color").action(.set_true))
        .arg(Arg.fromUsage("-c --color", "third flag").action(.set_true));
    const o = run(a, &cmd, &.{ "-f", "-c" });
    try testing.expect(o == .matches);
    try testing.expect(o.matches.getFlag("color"));
    try testing.expect(o.matches.getFlag("flag"));
}

test "option_required" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "option_required")
        .arg(Arg.fromUsage("f: -f <flag>", "some flag").requires("c"))
        .arg(Arg.fromUsage("c: -c <color>", "third flag"));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, errOf(a, &cmd, &.{ "-f", "val" }).kind);
}

test "option_required_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "option_required")
        .arg(Arg.fromUsage("f: -f <flag>", "some flag").requires("c"))
        .arg(Arg.fromUsage("c: -c <color>", "third flag"));
    const o = run(a, &cmd, &.{ "-f", "val", "-c", "other_val" });
    try testing.expect(o == .matches);
    try testing.expectEqualStrings("other_val", o.matches.getOne([]const u8, "c").?);
    try testing.expectEqualStrings("val", o.matches.getOne([]const u8, "f").?);
}

test "positional_required" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "positional_required")
        .arg(Arg.new("flag").required(true));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, errOf(a, &cmd, &.{}).kind);
}

test "positional_required_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "positional_required")
        .arg(Arg.new("flag").required(true));
    const o = run(a, &cmd, &.{"someval"});
    try testing.expect(o == .matches);
    try testing.expectEqualStrings("someval", o.matches.getOne([]const u8, "flag").?);
}

test "group_required" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "group_required")
        .arg(Arg.fromUsage("-f --flag", "some flag"))
        .group(ArgGroup.new("gr").required(true).args(&.{ "some", "other" }))
        .arg(Arg.fromUsage("--some", "some arg"))
        .arg(Arg.fromUsage("--other", "other arg"));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, errOf(a, &cmd, &.{"-f"}).kind);
}

test "group_required_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "group_required")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .group(ArgGroup.new("gr").required(true).args(&.{ "some", "other" }))
        .arg(Arg.fromUsage("--some", "some arg").action(.set_true))
        .arg(Arg.fromUsage("--other", "other arg").action(.set_true));
    const o = run(a, &cmd, &.{ "-f", "--some" });
    try testing.expect(o == .matches);
    try testing.expect(o.matches.getFlag("some"));
    try testing.expect(!o.matches.getFlag("other"));
    try testing.expect(o.matches.getFlag("flag"));
}

test "group_required_3" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "group_required")
        .arg(Arg.fromUsage("-f --flag", "some flag").action(.set_true))
        .group(ArgGroup.new("gr").required(true).args(&.{ "some", "other" }))
        .arg(Arg.fromUsage("--some", "some arg").action(.set_true))
        .arg(Arg.fromUsage("--other", "other arg").action(.set_true));
    const o = run(a, &cmd, &.{ "-f", "--other" });
    try testing.expect(o == .matches);
    try testing.expect(!o.matches.getFlag("some"));
    try testing.expect(o.matches.getFlag("other"));
    try testing.expect(o.matches.getFlag("flag"));
}

test "arg_require_group" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "arg_require_group")
        .arg(Arg.fromUsage("-f --flag", "some flag").requires("gr"))
        .group(ArgGroup.new("gr").args(&.{ "some", "other" }))
        .arg(Arg.fromUsage("--some", "some arg"))
        .arg(Arg.fromUsage("--other", "other arg"));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, errOf(a, &cmd, &.{"-f"}).kind);
}

test "arg_require_group_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "arg_require_group")
        .arg(Arg.fromUsage("-f --flag", "some flag").requires("gr").action(.set_true))
        .group(ArgGroup.new("gr").args(&.{ "some", "other" }))
        .arg(Arg.fromUsage("--some", "some arg").action(.set_true))
        .arg(Arg.fromUsage("--other", "other arg").action(.set_true));
    const o = run(a, &cmd, &.{ "-f", "--some" });
    try testing.expect(o == .matches);
    try testing.expect(o.matches.getFlag("some"));
    try testing.expect(!o.matches.getFlag("other"));
    try testing.expect(o.matches.getFlag("flag"));
}

test "arg_require_group_3" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "arg_require_group")
        .arg(Arg.fromUsage("-f --flag", "some flag").requires("gr").action(.set_true))
        .group(ArgGroup.new("gr").args(&.{ "some", "other" }))
        .arg(Arg.fromUsage("--some", "some arg").action(.set_true))
        .arg(Arg.fromUsage("--other", "other arg").action(.set_true));
    const o = run(a, &cmd, &.{ "-f", "--other" });
    try testing.expect(o == .matches);
    try testing.expect(!o.matches.getFlag("some"));
    try testing.expect(o.matches.getFlag("other"));
    try testing.expect(o.matches.getFlag("flag"));
}

test "positional_required_with_requires" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "clap-test")
        .arg(Arg.new("flag").required(true).requires("opt"))
        .arg(Arg.new("opt"))
        .arg(Arg.new("bar"));
    const o = run(a, &cmd, &.{});
    try testing.expectEqualStrings(
        "error: the following required arguments were not provided:\n" ++
            "  <flag>\n  <opt>\n\n" ++
            "Usage: clap-test <flag> <opt> [bar]\n\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, o.err),
    );
}

test "positional_required_with_requires_if_no_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "clap-test")
        .arg(Arg.new("flag").required(true).requiresIfs(&.{.{ .value = "val", .target = "opt" }}))
        .arg(Arg.new("opt"))
        .arg(Arg.new("bar"));
    const o = run(a, &cmd, &.{});
    try testing.expectEqualStrings(
        "error: the following required arguments were not provided:\n" ++
            "  <flag>\n\n" ++
            "Usage: clap-test <flag> [opt] [bar]\n\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, o.err),
    );
}

test "positional_required_with_requires_if_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "clap-test")
        .arg(Arg.new("flag").required(true).requiresIfs(&.{.{ .value = "val", .target = "opt" }}))
        .arg(Arg.new("foo").required(true))
        .arg(Arg.new("opt"))
        .arg(Arg.new("bar"));
    const o = run(a, &cmd, &.{"val"});
    try testing.expectEqualStrings(
        "error: the following required arguments were not provided:\n" ++
            "  <foo>\n  <opt>\n\n" ++
            "Usage: clap-test <flag> <foo> <opt> [bar]\n\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, o.err),
    );
}

test "requires_if_present_val" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("cfg").requiresIfs(&.{.{ .value = "my.cfg", .target = "extra" }}).action(.set).long("config"))
        .arg(Arg.new("extra").long("extra").action(.set_true));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, errOf(a, &cmd, &.{"--config=my.cfg"}).kind);
}

test "requires_if_present_mult" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("cfg").requiresIfs(&.{ .{ .value = "my.cfg", .target = "extra" }, .{ .value = "other.cfg", .target = "other" } }).action(.set).long("config"))
        .arg(Arg.new("extra").long("extra").action(.set_true))
        .arg(Arg.new("other").long("other").action(.set_true));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, errOf(a, &cmd, &.{"--config=other.cfg"}).kind);
}

test "requires_if_present_mult_pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("cfg").requiresIfs(&.{ .{ .value = "my.cfg", .target = "extra" }, .{ .value = "other.cfg", .target = "other" } }).action(.set).long("config"))
        .arg(Arg.new("extra").long("extra").action(.set_true))
        .arg(Arg.new("other").long("other").action(.set_true));
    try testing.expect(run(a, &cmd, &.{"--config=some.cfg"}) == .matches);
}

test "requires_if_present_val_no_present_pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "unlessone")
        .arg(Arg.new("cfg").requiresIfs(&.{.{ .value = "my.cfg", .target = "extra" }}).action(.set).long("config"))
        .arg(Arg.new("extra").long("extra").action(.set_true));
    try testing.expect(run(a, &cmd, &.{}) == .matches);
}

test "missing_required_output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = fixture.complexApp(a);
    cmd.buildTree();
    const o = clap.getMatches(a, &cmd, &.{"-F"});
    try testing.expectEqualStrings(
        "error: the following required arguments were not provided:\n" ++
            "  --long-option-2 <option2>\n  <positional>\n  <positional2>\n\n" ++
            "Usage: clap-test --long-option-2 <option2> -F <positional> <positional2> [positional3]...\n\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, o.err),
    );
}

test "list_correct_required_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .version("1.0")
        .author("F0x06")
        .about("Arg test")
        .arg(Arg.new("target").action(.set).required(true).valueParser(&.{ "file", "stdout" }).long("target"))
        .arg(Arg.new("input").action(.set).required(true).long("input"))
        .arg(Arg.new("output").action(.set).required(true).long("output"));
    const o = run(a, &cmd, &.{ "--input", "somepath", "--target", "file" });
    try testing.expectEqualStrings(
        "error: the following required arguments were not provided:\n" ++
            "  --output <output>\n\n" ++
            "Usage: test --target <target> --input <input> --output <output>\n\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, o.err),
    );
}
