const std = @import("std");
const clap = @import("clap");
const fixture = @import("fixture.zig");

const Fixture = fixture.Fixture;
const ErrorKind = clap.ErrorKind;
const testing = std.testing;

test "clone: required positional" {
    var f = Fixture.init();
    defer f.deinit();
    const m = f.run(&.{ "clone", "origin" }).matches;
    const sub = m.subcommand().?;
    try testing.expectEqualStrings("clone", sub.name);
    try testing.expectEqualStrings("origin", sub.matches.getOne([]const u8, "REMOTE").?);
}

test "diff: default and explicit color" {
    var f = Fixture.init();
    defer f.deinit();
    try testing.expectEqualStrings("auto", f.run(&.{"diff"}).matches.subcommand().?.matches.getOne([]const u8, "color").?);
    try testing.expectEqualStrings("never", f.run(&.{ "diff", "--color=never" }).matches.subcommand().?.matches.getOne([]const u8, "color").?);
    // bare --color uses default_missing_value
    try testing.expectEqualStrings("always", f.run(&.{ "diff", "--color" }).matches.subcommand().?.matches.getOne([]const u8, "color").?);
}

test "diff: positionals and last via --" {
    var f = Fixture.init();
    defer f.deinit();
    const a = f.run(&.{ "diff", "HEAD", "./src" }).matches.subcommand().?.matches;
    try testing.expectEqualStrings("HEAD", a.getOne([]const u8, "base").?);
    try testing.expectEqualStrings("./src", a.getOne([]const u8, "head").?);
    try testing.expect(a.getOne([]const u8, "path") == null);

    const b = f.run(&.{ "diff", "HEAD~~", "--", "HEAD" }).matches.subcommand().?.matches;
    try testing.expectEqualStrings("HEAD~~", b.getOne([]const u8, "base").?);
    try testing.expectEqualStrings("HEAD", b.getOne([]const u8, "path").?);
}

test "add: variadic positional" {
    var f = Fixture.init();
    defer f.deinit();
    const m = f.run(&.{ "add", "Cargo.toml", "Cargo.lock" }).matches.subcommand().?.matches;
    const paths = m.getMany([]const u8, "PATH").?;
    try testing.expectEqual(@as(usize, 2), paths.len);
    try testing.expectEqualStrings("Cargo.toml", paths[0]);
    try testing.expectEqualStrings("Cargo.lock", paths[1]);
}

test "stash: root option and nested subcommands" {
    var f = Fixture.init();
    defer f.deinit();
    const a = f.run(&.{ "stash", "-m", "msg" }).matches.subcommand().?.matches;
    try testing.expectEqualStrings("msg", a.getOne([]const u8, "message").?);
    try testing.expect(a.subcommand() == null);

    const push = f.run(&.{ "stash", "push", "-m", "msg" }).matches.subcommand().?.matches.subcommand().?;
    try testing.expectEqualStrings("push", push.name);
    try testing.expectEqualStrings("msg", push.matches.getOne([]const u8, "message").?);

    const pop = f.run(&.{ "stash", "pop" }).matches.subcommand().?.matches.subcommand().?;
    try testing.expectEqualStrings("pop", pop.name);
    try testing.expect(pop.matches.getOne([]const u8, "STASH") == null);
}

test "external subcommand" {
    var f = Fixture.init();
    defer f.deinit();
    const sub = f.run(&.{ "custom-tool", "arg1", "--foo", "bar" }).matches.subcommand().?;
    try testing.expectEqualStrings("custom-tool", sub.name);
    const args = sub.matches.getMany([]const u8, clap.external_id).?;
    try testing.expectEqual(@as(usize, 3), args.len);
    try testing.expectEqualStrings("arg1", args[0]);
    try testing.expectEqualStrings("--foo", args[1]);
    try testing.expectEqualStrings("bar", args[2]);
}

test "help requests" {
    var f = Fixture.init();
    defer f.deinit();
    try testing.expectEqual(ErrorKind.display_help, f.run(&.{"--help"}).err.kind);
    const h = f.run(&.{ "help", "add" }).err;
    try testing.expectEqual(ErrorKind.display_help, h.kind);
    try testing.expectEqualStrings("add", h.cmd.name);
}

test "validate: arg_required_else_help on empty command" {
    var f = Fixture.init();
    defer f.deinit();
    const g = f.runValidated(&.{}).err;
    try testing.expectEqual(ErrorKind.display_help_on_missing_argument_or_subcommand, g.kind);
    try testing.expectEqualStrings("git", g.cmd.name);
    const a = f.runValidated(&.{"add"}).err;
    try testing.expectEqual(ErrorKind.display_help_on_missing_argument_or_subcommand, a.kind);
    try testing.expectEqualStrings("add", a.cmd.name);
}

test "validate: invalid possible value" {
    var f = Fixture.init();
    defer f.deinit();
    const e = f.runValidated(&.{ "diff", "--color=bad" }).err;
    try testing.expectEqual(ErrorKind.invalid_value, e.kind);
    try testing.expectEqualStrings("bad", e.value.?);
    try testing.expectEqualStrings("--color <WHEN>", e.arg.?);
}

test "validate: happy paths return matches" {
    var f = Fixture.init();
    defer f.deinit();
    try testing.expect(f.runValidated(&.{ "clone", "origin" }) == .matches);
    try testing.expect(f.runValidated(&.{ "diff", "--color=never" }) == .matches);
    try testing.expect(f.runValidated(&.{ "add", "x" }) == .matches);
}
