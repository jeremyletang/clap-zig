//! Ported subset of clap's tests/builder/arg_aliases.rs + arg_aliases_short.rs —
//! arg long/short aliases (invisible + visible). The `🦆` non-ASCII short-alias
//! case is deferred (our short aliases are bytes, not full chars).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/arg_aliases.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

fn helpText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, argv).err);
}

test "single_alias_of_option" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "single_alias")
        .arg(Arg.new("alias").long("alias").action(.set).help("single alias").aliases(&.{"new-opt"}));
    const m = run(a, &cmd, &.{ "--new-opt", "cool" }).matches;
    try testing.expect(m.contains("alias"));
    try testing.expectEqualStrings("cool", m.getOne([]const u8, "alias").?);
}

test "multiple_aliases_of_option" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const mk = struct {
        fn f(al: std.mem.Allocator) Command {
            return Command.init(al, "multiple_aliases")
                .arg(Arg.new("aliases").long("aliases").action(.set).aliases(&.{ "alias1", "alias2", "alias3" }));
        }
    }.f;
    inline for (.{ "--aliases", "--alias1", "--alias2", "--alias3" }) |name| {
        var cmd = mk(a);
        const m = run(a, &cmd, &.{ name, "value" }).matches;
        try testing.expect(m.contains("aliases"));
        try testing.expectEqualStrings("value", m.getOne([]const u8, "aliases").?);
    }
}

test "single_alias_of_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.new("flag").long("flag").aliases(&.{"alias"}).action(.set_true));
    try testing.expect(run(a, &cmd, &.{"--alias"}).matches.getFlag("flag"));
}

test "multiple_aliases_of_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const mk = struct {
        fn f(al: std.mem.Allocator) Command {
            return Command.init(al, "test")
                .arg(Arg.new("flag").long("flag").aliases(&.{ "invisible", "set", "of", "cool", "aliases" }).action(.set_true));
        }
    }.f;
    inline for (.{ "--flag", "--invisible", "--cool", "--aliases" }) |name| {
        var cmd = mk(a);
        try testing.expect(run(a, &cmd, &.{name}).matches.getFlag("flag"));
    }
}

test "alias_on_a_subcommand_option" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .subcommand(Command.init(a, "some")
            .arg(Arg.new("test").short('t').long("test").action(.set).aliases(&.{"opt"}).help("testing testing")))
        .arg(Arg.new("other").long("other").aliases(&.{ "o1", "o2", "o3" }));
    const m = run(a, &cmd, &.{ "some", "--opt", "awesome" }).matches;
    const sub = m.subcommand().?;
    try testing.expectEqualStrings("some", sub.name);
    try testing.expect(sub.matches.contains("test"));
    try testing.expectEqualStrings("awesome", sub.matches.getOne([]const u8, "test").?);
}

test "single_short_alias_of_option" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.new("alias").short('f').action(.set).shortAliases("a"));
    const m = run(a, &cmd, &.{ "-a", "cool" }).matches;
    try testing.expect(m.contains("alias"));
    try testing.expectEqualStrings("cool", m.getOne([]const u8, "alias").?);
}

test "multiple_short_aliases_of_option" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const mk = struct {
        fn f(al: std.mem.Allocator) Command {
            return Command.init(al, "test")
                .arg(Arg.new("aliases").short('a').action(.set).shortAliases("123"));
        }
    }.f;
    inline for (.{ 'a', '1', '2', '3' }) |c| {
        var cmd = mk(a);
        const m = run(a, &cmd, &.{ &[_]u8{ '-', c }, "value" }).matches;
        try testing.expect(m.contains("aliases"));
        try testing.expectEqualStrings("value", m.getOne([]const u8, "aliases").?);
    }
}

test "single_short_alias_of_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.new("flag").long("flag").short('a').shortAliases("f").action(.set_true));
    try testing.expect(run(a, &cmd, &.{"-f"}).matches.getFlag("flag"));
}

test "invisible_arg_aliases_help_output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ct").subcommand(Command.init(a, "test").about("Some help").version("1.2")
        .arg(Arg.new("opt").long("opt").short('o').action(.set).aliases(&.{ "invisible", "als1", "more" }))
        .arg(Arg.new("flag").long("flag").short('f').action(.set_true).aliases(&.{ "unseeable", "flg1", "anyway" })));
    try testing.expectEqualStrings(
        "Some help\n\n" ++
            "Usage: ct test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -o, --opt <opt>  \n" ++
            "  -f, --flag       \n" ++
            "  -h, --help       Print help\n" ++
            "  -V, --version    Print version\n",
        helpText(a, &cmd, &.{ "test", "--help" }),
    );
}

test "visible_arg_aliases_help_output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ct").subcommand(Command.init(a, "test").about("Some help").version("1.2")
        .arg(Arg.new("opt").long("opt").short('o').action(.set).aliases(&.{"invisible"}).visibleAliases(&.{"visible"}))
        .arg(Arg.new("flg").long("flag").short('f').action(.set_true).visibleAliases(&.{ "v_flg", "flag2", "flg3" })));
    try testing.expectEqualStrings(
        "Some help\n\n" ++
            "Usage: ct test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -o, --opt <opt>  [aliases: --visible]\n" ++
            "  -f, --flag       [aliases: --v_flg, --flag2, --flg3]\n" ++
            "  -h, --help       Print help\n" ++
            "  -V, --version    Print version\n",
        helpText(a, &cmd, &.{ "test", "--help" }),
    );
}

test "visible_short_arg_aliases_help_output (ascii)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ct").subcommand(Command.init(a, "test").about("Some help").version("1.2")
        .arg(Arg.new("opt").long("opt").short('o').action(.set).shortAliases("i").visibleShortAliases("v"))
        .arg(Arg.new("flg").long("flag").short('f').action(.set_true).visibleAliases(&.{"flag1"}).visibleShortAliases("ab")));
    try testing.expectEqualStrings(
        "Some help\n\n" ++
            "Usage: ct test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -o, --opt <opt>  [aliases: -v]\n" ++
            "  -f, --flag       [aliases: -a, -b, --flag1]\n" ++
            "  -h, --help       Print help\n" ++
            "  -V, --version    Print version\n",
        helpText(a, &cmd, &.{ "test", "--help" }),
    );
}

// ----- subcommand aliases (subcommands.rs) -----

test "single_alias (subcommand)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog").subcommand(Command.init(a, "test").aliases(&.{"do-stuff"}));
    const m = run(a, &cmd, &.{"do-stuff"}).matches;
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

test "multiple_aliases (subcommand)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog").subcommand(Command.init(a, "test").aliases(&.{ "do-stuff", "test-stuff" }));
    const m = run(a, &cmd, &.{"test-stuff"}).matches;
    try testing.expectEqualStrings("test", m.subcommand().?.name);
}

test "alias_help (subcommand)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog").subcommand(Command.init(a, "test").aliases(&.{"do-stuff"}));
    try testing.expectEqual(clap.ErrorKind.display_help, run(a, &cmd, &.{ "help", "do-stuff" }).err.kind);
}

test "visible_aliases_help_output (subcommand)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "clap-test").version("2.6")
        .subcommand(Command.init(a, "test").about("Some help").aliases(&.{"invisible"}).visibleAliases(&.{ "dongle", "done" }));
    try testing.expectEqualStrings(
        "Usage: clap-test [COMMAND]\n\n" ++
            "Commands:\n" ++
            "  test  Some help [aliases: dongle, done]\n" ++
            "  help  Print this message or the help of the given subcommand(s)\n\n" ++
            "Options:\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "invisible_aliases_help_output (subcommand)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "clap-test").version("2.6")
        .subcommand(Command.init(a, "test").about("Some help").aliases(&.{"invisible"}));
    try testing.expectEqualStrings(
        "Usage: clap-test [COMMAND]\n\n" ++
            "Commands:\n" ++
            "  test  Some help\n" ++
            "  help  Print this message or the help of the given subcommand(s)\n\n" ++
            "Options:\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}
