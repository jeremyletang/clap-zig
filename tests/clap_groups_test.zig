//! Ported from clap's tests/builder/groups.rs — `ArgGroup` behavior: required
//! groups, mutual exclusion, group-as-arg queries (`get_one`/`get_many` over a
//! group return the matched member ids), and group usage tokens.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/groups.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const ArgGroup = clap.ArgGroup;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn errText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    return clap.renderError(a, run(a, cmd, argv).err);
}

fn flag(id: []const u8, s: u8) Arg {
    return Arg.new(id).short(s).long(id).action(.set_true);
}

test "required_group_missing_arg" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "group")
        .arg(flag("flag", 'f'))
        .arg(flag("color", 'c'))
        .group(ArgGroup.new("req").args(&.{ "flag", "color" }).required(true));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{}).err.kind);
}

test "group_single_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "group")
        .arg(Arg.new("color").short('c').long("color").action(.set))
        .arg(Arg.new("hostname").short('n').long("hostname").action(.set))
        .group(ArgGroup.new("grp").args(&.{ "hostname", "color" }));
    const m = run(a, &cmd, &.{ "-c", "blue" }).matches;
    try testing.expect(m.contains("grp"));
    try testing.expectEqualStrings("color", m.getOne([]const u8, "grp").?);
}

test "group_empty" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "group")
        .arg(flag("flag", 'f'))
        .arg(Arg.new("color").short('c').long("color").action(.set))
        .arg(Arg.new("hostname").short('n').long("hostname").action(.set))
        .group(ArgGroup.new("grp").args(&.{ "hostname", "color", "flag" }));
    const m = run(a, &cmd, &.{}).matches;
    try testing.expect(!m.contains("grp"));
    try testing.expect(m.getOne([]const u8, "grp") == null);
}

test "group_required_flags_empty" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "group")
        .arg(flag("flag", 'f'))
        .arg(flag("color", 'c'))
        .arg(Arg.new("hostname").short('n').long("hostname").action(.set))
        .group(ArgGroup.new("grp").required(true).args(&.{ "hostname", "color", "flag" }));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{}).err.kind);
}

test "group_multi_value_single_arg" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "group")
        .arg(flag("flag", 'f'))
        .arg(Arg.new("color").short('c').long("color").action(.set).numArgs(clap.ValueRange.atLeast(1)))
        .arg(Arg.new("hostname").short('n').long("hostname").action(.set))
        .group(ArgGroup.new("grp").args(&.{ "hostname", "color", "flag" }));
    const m = run(a, &cmd, &.{ "-c", "blue", "red", "green" }).matches;
    try testing.expect(m.contains("grp"));
    try testing.expectEqualStrings("color", m.getOne([]const u8, "grp").?);
}

test "empty_group" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "empty_group")
        .arg(flag("flag", 'f'))
        .group(ArgGroup.new("vers").required(true));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{}).err.kind);
}

test "req_group_usage_string" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "clap-test")
        .arg(Arg.new("base"))
        .arg(Arg.new("delete").short('d').long("delete").action(.set_true))
        .group(ArgGroup.new("base_or_delete").args(&.{ "base", "delete" }).required(true));
    try testing.expectEqualStrings(
        "error: the following required arguments were not provided:\n" ++
            "  <base|--delete>\n\n" ++
            "Usage: clap-test <base|--delete>\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{}),
    );
}

test "req_group_with_conflict_usage_string" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "clap-test")
        .arg(Arg.new("base").conflictsWith(&.{"delete"}))
        .arg(Arg.new("delete").short('d').long("delete").action(.set_true))
        .group(ArgGroup.new("base_or_delete").args(&.{ "base", "delete" }).required(true));
    try testing.expectEqualStrings(
        "error: the argument '--delete' cannot be used with '[base]'\n\n" ++
            "Usage: clap-test <base|--delete>\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{ "--delete", "base" }),
    );
}

test "req_group_with_conflict_usage_string_only_options" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "clap-test")
        .arg(Arg.new("all").short('a').long("all").action(.set_true).conflictsWith(&.{"delete"}))
        .arg(Arg.new("delete").short('d').long("delete").action(.set_true))
        .group(ArgGroup.new("all_or_delete").args(&.{ "all", "delete" }).required(true));
    try testing.expectEqualStrings(
        "error: the argument '--delete' cannot be used with '--all'\n\n" ++
            "Usage: clap-test <--all|--delete>\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{ "--delete", "--all" }),
    );
}

test "required_group_multiple_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "group")
        .arg(flag("flag", 'f'))
        .arg(flag("color", 'c'))
        .group(ArgGroup.new("req").args(&.{ "flag", "color" }).required(true).multiple(true));
    const m = run(a, &cmd, &.{ "-f", "-c" }).matches;
    try testing.expect(m.getFlag("flag"));
    try testing.expect(m.getFlag("color"));
    const req = m.getMany([]const u8, "req").?;
    try testing.expectEqual(@as(usize, 2), req.len);
    try testing.expectEqualStrings("flag", req[0]);
    try testing.expectEqualStrings("color", req[1]);
}

test "group_multiple_args_error" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "group")
        .arg(flag("flag", 'f'))
        .arg(flag("color", 'c'))
        .group(ArgGroup.new("req").args(&.{ "flag", "color" }));
    try testing.expectEqual(clap.ErrorKind.argument_conflict, run(a, &cmd, &.{ "-f", "-c" }).err.kind);
}

test "group_overrides_required" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "group")
        .arg(Arg.new("foo").long("foo").action(.set).required(true))
        .arg(Arg.new("bar").long("bar").action(.set).required(true))
        .group(ArgGroup.new("group").args(&.{ "foo", "bar" }).required(true));
    const m = run(a, &cmd, &.{ "--foo", "value" }).matches;
    try testing.expect(m.contains("foo"));
    try testing.expect(!m.contains("bar"));
}

test "group_usage_use_val_name" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("a").valueName("A"))
        .group(ArgGroup.new("group").args(&.{"a"}).required(true));
    try testing.expectEqualStrings(
        "Usage: prog <A>\n\n" ++
            "Arguments:\n  [A]  \n\n" ++
            "Options:\n  -h, --help  Print help\n",
        errText(a, &cmd, &.{"--help"}),
    );
}

test "group_acts_like_arg" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog")
        .arg(Arg.new("debug").long("debug").action(.set_true).group("mode"))
        .arg(Arg.new("verbose").long("verbose").action(.set_true).group("mode"));
    const m = run(a, &cmd, &.{"--debug"}).matches;
    try testing.expect(m.contains("mode"));
    try testing.expectEqualStrings("debug", m.getOne([]const u8, "mode").?);
}
