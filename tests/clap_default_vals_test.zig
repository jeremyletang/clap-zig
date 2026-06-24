//! Ported from clap's tests/builder/default_vals.rs — default_value / default_values
//! (plural), default_value_if / default_values_if conditionals, value source, and
//! interaction with required args/groups. (OsStr, value-parser, and
//! dont_delimit_trailing_values cases are out of scope.)
//! https://github.com/clap-rs/clap/blob/master/tests/builder/default_vals.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const ArgGroup = clap.ArgGroup;
const range = clap.ValueRange;
const DVI = clap.DefaultValueIf;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn errText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    return clap.renderError(a, run(a, cmd, argv).err);
}

// ----- basic default_value -----

test "opts (default value source)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df").arg(Arg.new("o").short('o').action(.set).defaultValue("default"));
    const m = run(a, &cmd, &.{}).matches;
    try testing.expect(m.contains("o"));
    try testing.expectEqual(@as(?clap.ValueSource, .default_value), m.valueSource("o"));
    try testing.expectEqualStrings("default", m.getOne([]const u8, "o").?);
}

test "positionals (default value source)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df").arg(Arg.new("arg").defaultValue("default"));
    const m = run(a, &cmd, &.{}).matches;
    try testing.expectEqual(@as(?clap.ValueSource, .default_value), m.valueSource("arg"));
    try testing.expectEqualStrings("default", m.getOne([]const u8, "arg").?);
}

test "opt_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df").arg(Arg.new("opt").long("opt").action(.set).defaultValue("default"));
    const m = run(a, &cmd, &.{ "--opt", "value" }).matches;
    try testing.expectEqual(@as(?clap.ValueSource, .command_line), m.valueSource("opt"));
    try testing.expectEqualStrings("value", m.getOne([]const u8, "opt").?);
}

test "positional_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df").arg(Arg.new("arg").defaultValue("default"));
    const m = run(a, &cmd, &.{"value"}).matches;
    try testing.expectEqual(@as(?clap.ValueSource, .command_line), m.valueSource("arg"));
    try testing.expectEqualStrings("value", m.getOne([]const u8, "arg").?);
}

test "default_has_index" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df").arg(Arg.new("o").short('o').action(.set).defaultValue("default"));
    try testing.expectEqual(@as(?usize, 1), run(a, &cmd, &.{}).matches.indexOf("o"));
}

test "issue_1050_num_vals_and_defaults" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "hello")
        .arg(Arg.new("exit-code").long("exit-code").action(.set).numArgs(range.between(1, 1)).defaultValue("0"));
    try testing.expectEqualStrings("1", run(a, &cmd, &.{"--exit-code=1"}).matches.getOne([]const u8, "exit-code").?);
}

test "conditional_reqs_pass" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "Test cmd")
        .arg(Arg.new("target").action(.set).defaultValue("file").long("target"))
        .arg(Arg.new("input").action(.set).required(true).long("input"))
        .arg(Arg.new("output").action(.set).requiredIfEqAny(&.{.{ .target = "target", .value = "file" }}).long("output"));
    const m = run(a, &cmd, &.{ "--input", "some", "--output", "other" }).matches;
    try testing.expectEqualStrings("other", m.getOne([]const u8, "output").?);
    try testing.expectEqualStrings("some", m.getOne([]const u8, "input").?);
}

test "default_vals_donnot_show_in_smart_usage" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "bug")
        .arg(Arg.new("foo").long("config").action(.set).defaultValue("bar"))
        .arg(Arg.new("input").required(true));
    try testing.expectEqualStrings(
        "error: the following required arguments were not provided:\n" ++
            "  <input>\n\n" ++
            "Usage: bug <input>\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{}),
    );
}

test "required_args_with_default_values" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "test").arg(Arg.new("arg").required(true).defaultValue("value"));
    try testing.expect(!run(a, &c1, &.{}).err.kind.isSuccess());
    var c2 = Command.init(a, "test").arg(Arg.new("arg").required(true).defaultValue("value"));
    try testing.expect(run(a, &c2, &.{"value"}).matches.contains("arg"));
}

test "required_groups_with_default_values" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = Command.init(a, "test")
        .arg(Arg.new("arg").defaultValue("value"))
        .group(ArgGroup.new("group").args(&.{"arg"}).required(true));
    try testing.expect(!run(a, &c1, &.{}).err.kind.isSuccess());
    var c2 = Command.init(a, "test")
        .arg(Arg.new("arg").defaultValue("value"))
        .group(ArgGroup.new("group").args(&.{"arg"}).required(true));
    const m = run(a, &c2, &.{"value"}).matches;
    try testing.expect(m.contains("arg"));
    try testing.expect(m.contains("group"));
}

// ----- plural default_values -----

test "multiple_defaults" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "diff").arg(Arg.new("files").long("files").numArgs(range.between(2, 2)).defaultValues(&.{ "old", "new" }));
    const f = run(a, &cmd, &.{}).matches.getMany([]const u8, "files").?;
    try testing.expectEqual(@as(usize, 2), f.len);
    try testing.expectEqualStrings("old", f[0]);
    try testing.expectEqualStrings("new", f[1]);
}

test "multiple_defaults_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "diff").arg(Arg.new("files").long("files").numArgs(range.between(2, 2)).defaultValues(&.{ "old", "new" }));
    const f = run(a, &cmd, &.{ "--files", "other", "mine" }).matches.getMany([]const u8, "files").?;
    try testing.expectEqualStrings("other", f[0]);
    try testing.expectEqualStrings("mine", f[1]);
}

// ----- default_value_if (single) -----

fn dfIf(a: std.mem.Allocator, with_default: bool) Command {
    var arg = Arg.new("arg").defaultValueIfs(&.{.{ .arg = "opt", .equals = "some", .value = &.{"default"} }});
    if (with_default) arg = arg.defaultValue("first");
    return Command.init(a, "df")
        .arg(Arg.new("opt").long("opt").action(.set))
        .arg(arg);
}

fn argVal(o: clap.Outcome) ?[]const u8 {
    return o.matches.getOne([]const u8, "arg");
}

test "default_if_arg_present_no_arg_with_value_with_default_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dfIf(a, true);
    try testing.expectEqualStrings("other", argVal(run(a, &cmd, &.{"other"})).?);
}

test "default_if_arg_present_no_arg_with_value_with_default_user_override_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dfIf(a, true);
    try testing.expectEqualStrings("other", argVal(run(a, &cmd, &.{ "--opt", "value", "other" })).?);
}

test "default_if_arg_present_with_value_no_arg_with_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dfIf(a, true);
    try testing.expectEqualStrings("first", argVal(run(a, &cmd, &.{})).?);
}

test "default_if_arg_present_with_value_no_arg_with_default_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dfIf(a, true);
    try testing.expectEqualStrings("first", argVal(run(a, &cmd, &.{ "--opt", "other" })).?);
}

test "default_if_arg_present_with_value_no_default_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dfIf(a, false);
    try testing.expectEqualStrings("other", argVal(run(a, &cmd, &.{ "--opt", "some", "other" })).?);
}

test "default_if_arg_present_with_value_with_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dfIf(a, true);
    try testing.expectEqualStrings("default", argVal(run(a, &cmd, &.{ "--opt", "some" })).?);
}

test "default_if_arg_present_with_value_with_default_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dfIf(a, true);
    try testing.expectEqualStrings("other", argVal(run(a, &cmd, &.{ "--opt", "some", "other" })).?);
}

test "default_ifs_arg_present_order" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.new("opt").long("opt").action(.set))
        .arg(Arg.new("flag").long("flag").action(.set_true))
        .arg(Arg.new("arg").defaultValue("first").defaultValueIfs(&.{
        .{ .arg = "opt", .equals = "some", .value = &.{"default"} },
        .{ .arg = "flag", .value = &.{"flg"} },
    }));
    try testing.expectEqualStrings("default", argVal(run(a, &cmd, &.{ "--opt=some", "--flag" })).?);
}

// ----- default_values_if (plural) -----

fn dvIf(a: std.mem.Allocator, with_default: bool) Command {
    var arg = Arg.new("args").long("args").numArgs(range.between(2, 2))
        .defaultValueIfs(&.{.{ .arg = "opt", .equals = "value", .value = &.{ "df1", "df2" } }});
    if (with_default) arg = arg.defaultValues(&.{ "first", "second" });
    return Command.init(a, "df").arg(Arg.new("opt").long("opt").action(.set)).arg(arg);
}

fn args2(o: clap.Outcome) ?[]const []const u8 {
    return o.matches.getMany([]const u8, "args");
}

test "default_values_if_arg_present_no_arg_with_value_with_default_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dvIf(a, true);
    const v = args2(run(a, &cmd, &.{ "--args", "other1", "other2" })).?;
    try testing.expectEqualStrings("other1", v[0]);
    try testing.expectEqualStrings("other2", v[1]);
}

test "default_values_if_arg_present_no_arg_with_value_with_default_user_override_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dvIf(a, true);
    const v = args2(run(a, &cmd, &.{ "--opt", "some", "--args", "other1", "other2" })).?;
    try testing.expectEqualStrings("other1", v[0]);
    try testing.expectEqualStrings("other2", v[1]);
}

test "default_values_if_arg_present_with_value_no_arg_with_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dvIf(a, true);
    const v = args2(run(a, &cmd, &.{})).?;
    try testing.expectEqualStrings("first", v[0]);
    try testing.expectEqualStrings("second", v[1]);
}

test "default_values_if_arg_present_with_value_no_arg_with_default_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dvIf(a, true);
    const v = args2(run(a, &cmd, &.{ "--opt", "other" })).?;
    try testing.expectEqualStrings("first", v[0]);
    try testing.expectEqualStrings("second", v[1]);
}

test "default_values_if_arg_present_with_value_no_default_fail" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dvIf(a, false);
    const m = run(a, &cmd, &.{ "--opt", "other" }).matches;
    try testing.expect(!m.contains("args"));
    try testing.expect(m.getMany([]const u8, "args") == null);
}

test "default_values_if_arg_present_with_value_no_default_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dvIf(a, false);
    const v = args2(run(a, &cmd, &.{ "--opt", "value", "--args", "old", "new" })).?;
    try testing.expectEqualStrings("old", v[0]);
    try testing.expectEqualStrings("new", v[1]);
}

test "default_values_if_arg_present_with_value_with_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dvIf(a, true);
    const v = args2(run(a, &cmd, &.{ "--opt", "value" })).?;
    try testing.expectEqualStrings("df1", v[0]);
    try testing.expectEqualStrings("df2", v[1]);
}

test "default_values_if_arg_present_with_value_with_default_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = dvIf(a, true);
    const v = args2(run(a, &cmd, &.{ "--opt", "value", "--args", "other1", "other2" })).?;
    try testing.expectEqualStrings("other1", v[0]);
    try testing.expectEqualStrings("other2", v[1]);
}

test "default_values_ifs_arg_present_order" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "df")
        .arg(Arg.new("opt").long("opt").action(.set))
        .arg(Arg.new("flag").long("flag").action(.set_true))
        .arg(Arg.new("args").long("args").numArgs(range.between(2, 2)).defaultValues(&.{ "first", "second" }).defaultValueIfs(&.{
        .{ .arg = "opt", .equals = "some", .value = &.{ "d1", "d2" } },
        .{ .arg = "flag", .value = &.{ "d3", "d4" } },
    }));
    const v = args2(run(a, &cmd, &.{ "--opt=some", "--flag" })).?;
    try testing.expectEqualStrings("d1", v[0]);
    try testing.expectEqualStrings("d2", v[1]);
}
