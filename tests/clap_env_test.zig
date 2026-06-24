//! Ported subset of clap's tests/builder/env.rs — `Arg.env` fallback. Env values
//! are supplied via an injected `EnvSource` (the library stays IO-free), with
//! precedence CLI > env > default. The `FalseyValueParser` (env_bool_literal)
//! and OsStr variants are deferred.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/env.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const range = clap.ValueRange;

/// Build an EnvSource over the given name→value pairs.
fn envWith(map: *std.StringHashMap([]const u8), pairs: []const [2][]const u8) clap.EnvSource {
    for (pairs) |p| map.put(p[0], p[1]) catch @panic("OOM");
    return clap.mapEnvSource(map);
}

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8, src: clap.EnvSource) clap.Outcome {
    cmd.buildTree();
    return clap.getMatchesEnv(a, cmd, argv, src);
}

test "env" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var map = std.StringHashMap([]const u8).init(a);
    const src = envWith(&map, &.{.{ "CLP_TEST_ENV", "env" }});
    var cmd = Command.init(a, "df").arg(Arg.new("arg").env("CLP_TEST_ENV").action(.set));
    const m = run(a, &cmd, &.{}, src).matches;
    try testing.expect(m.contains("arg"));
    try testing.expectEqual(clap.ValueSource.env, m.valueSource("arg").?);
    try testing.expectEqualStrings("env", m.getOne([]const u8, "arg").?);
}

test "no_env" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var map = std.StringHashMap([]const u8).init(a);
    const src = clap.mapEnvSource(&map); // empty
    var cmd = Command.init(a, "df").arg(Arg.new("arg").env("CLP_TEST_ENV_NONE").action(.set));
    const m = run(a, &cmd, &.{}, src).matches;
    try testing.expect(!m.contains("arg"));
    try testing.expectEqual(@as(?clap.ValueSource, null), m.valueSource("arg"));
    try testing.expect(m.getOne([]const u8, "arg") == null);
}

test "with_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var map = std.StringHashMap([]const u8).init(a);
    const src = envWith(&map, &.{.{ "CLP_TEST_ENV_WD", "env" }});
    var cmd = Command.init(a, "df").arg(Arg.new("arg").env("CLP_TEST_ENV_WD").action(.set).defaultValue("default"));
    const m = run(a, &cmd, &.{}, src).matches;
    try testing.expectEqual(clap.ValueSource.env, m.valueSource("arg").?);
    try testing.expectEqualStrings("env", m.getOne([]const u8, "arg").?);
}

test "opt_user_override" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var map = std.StringHashMap([]const u8).init(a);
    const src = envWith(&map, &.{.{ "CLP_TEST_ENV_OR", "env" }});
    var cmd = Command.init(a, "df").arg(Arg.new("arg").long("arg").env("CLP_TEST_ENV_OR").action(.set));
    const m = run(a, &cmd, &.{ "--arg", "opt" }, src).matches;
    try testing.expectEqual(clap.ValueSource.command_line, m.valueSource("arg").?);
    try testing.expectEqualStrings("opt", m.getOne([]const u8, "arg").?);
    const vals = m.getMany([]const u8, "arg").?;
    try testing.expectEqual(@as(usize, 1), vals.len);
    try testing.expectEqualStrings("opt", vals[0]);
}

test "multiple_one" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var map = std.StringHashMap([]const u8).init(a);
    const src = envWith(&map, &.{.{ "CLP_TEST_ENV_MO", "env" }});
    var cmd = Command.init(a, "df").arg(Arg.new("arg").env("CLP_TEST_ENV_MO").action(.set).valueDelimiter(',').numArgs(range.atLeast(1)));
    const vals = run(a, &cmd, &.{}, src).matches.getMany([]const u8, "arg").?;
    try testing.expectEqual(@as(usize, 1), vals.len);
    try testing.expectEqualStrings("env", vals[0]);
}

test "multiple_three" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var map = std.StringHashMap([]const u8).init(a);
    const src = envWith(&map, &.{.{ "CLP_TEST_ENV_MULTI1", "env1,env2,env3" }});
    var cmd = Command.init(a, "df").arg(Arg.new("arg").env("CLP_TEST_ENV_MULTI1").action(.set).valueDelimiter(',').numArgs(range.atLeast(1)));
    const vals = run(a, &cmd, &.{}, src).matches.getMany([]const u8, "arg").?;
    try testing.expectEqual(@as(usize, 3), vals.len);
    try testing.expectEqualStrings("env1", vals[0]);
    try testing.expectEqualStrings("env2", vals[1]);
    try testing.expectEqualStrings("env3", vals[2]);
}

test "multiple_no_delimiter" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var map = std.StringHashMap([]const u8).init(a);
    const src = envWith(&map, &.{.{ "CLP_TEST_ENV_MULTI2", "env1 env2 env3" }});
    var cmd = Command.init(a, "df").arg(Arg.new("arg").env("CLP_TEST_ENV_MULTI2").action(.set).numArgs(range.atLeast(1)));
    const vals = run(a, &cmd, &.{}, src).matches.getMany([]const u8, "arg").?;
    try testing.expectEqual(@as(usize, 1), vals.len);
    try testing.expectEqualStrings("env1 env2 env3", vals[0]);
}

test "possible_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var map = std.StringHashMap([]const u8).init(a);
    const src = envWith(&map, &.{.{ "CLP_TEST_ENV_PV", "env" }});
    var cmd = Command.init(a, "df").arg(Arg.new("arg").env("CLP_TEST_ENV_PV").action(.set).valueParser(&.{"env"}));
    const m = run(a, &cmd, &.{}, src).matches;
    try testing.expectEqualStrings("env", m.getOne([]const u8, "arg").?);
}

test "not_possible_value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var map = std.StringHashMap([]const u8).init(a);
    const src = envWith(&map, &.{.{ "CLP_TEST_ENV_NPV", "env" }});
    var cmd = Command.init(a, "df").arg(Arg.new("arg").env("CLP_TEST_ENV_NPV").action(.set).valueParser(&.{"never"}));
    try testing.expect(run(a, &cmd, &.{}, src) == .err);
}
