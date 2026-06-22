//! Ported subset of clap's tests/builder/hidden_args.rs — `hide(true)` on args,
//! positionals, and subcommands (omitted from help + usage). The per-mode
//! `hide_short_help`/`hide_long_help` cases are deferred.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/hidden_args.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const PossibleValue = clap.PossibleValue;

fn help(a: std.mem.Allocator, cmd: *Command) []const u8 {
    cmd.buildTree();
    return clap.renderHelp(a, cmd);
}

test "hide_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").about("tests stuff").version("1.4")
        .arg(Arg.fromUsage("-f --flag", "some flag").hide(true))
        .arg(Arg.fromUsage("-F --flag2", "some other flag"))
        .arg(Arg.fromUsage("--option <opt>", "some option"))
        .arg(Arg.new("DUMMY").hide(true));
    try testing.expectEqualStrings(
        "tests stuff\n\n" ++
            "Usage: test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -F, --flag2         some other flag\n" ++
            "      --option <opt>  some option\n" ++
            "  -h, --help          Print help\n" ++
            "  -V, --version       Print version\n",
        help(a, &cmd),
    );
}

test "hide_pos_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.4")
        .arg(Arg.new("pos").help("some pos").hide(true))
        .arg(Arg.new("another").help("another pos"));
    try testing.expectEqualStrings(
        "Usage: test [another]\n\n" ++
            "Arguments:\n" ++
            "  [another]  another pos\n\n" ++
            "Options:\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n",
        help(a, &cmd),
    );
}

test "hide_subcmds" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.4")
        .subcommand(Command.init(a, "sub").hide(true));
    try testing.expectEqualStrings(
        "Usage: test\n\n" ++
            "Options:\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n",
        help(a, &cmd),
    );
}

test "hide_opt_args_only" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.4").afterHelp("After help")
        .disableHelpFlag(true).disableVersionFlag(true)
        .arg(Arg.fromUsage("-h --help", null).action(.help).hide(true))
        .arg(Arg.fromUsage("-v --version", null).hide(true))
        .arg(Arg.fromUsage("--option <opt>", "some option").hide(true));
    try testing.expectEqualStrings("Usage: test\n\nAfter help\n", help(a, &cmd));
}

test "hide_pos_args_only" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.4").afterHelp("After help")
        .disableHelpFlag(true).disableVersionFlag(true)
        .arg(Arg.fromUsage("-h --help", null).action(.help).hide(true))
        .arg(Arg.fromUsage("-v --version", null).hide(true))
        .arg(Arg.new("pos").help("some pos").hide(true));
    try testing.expectEqualStrings("Usage: test\n\nAfter help\n", help(a, &cmd));
}

test "hide_subcmds_only" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.4").afterHelp("After help")
        .disableHelpFlag(true).disableVersionFlag(true)
        .arg(Arg.fromUsage("-h --help", null).action(.help).hide(true))
        .arg(Arg.fromUsage("-v --version", null).hide(true))
        .subcommand(Command.init(a, "sub").hide(true));
    try testing.expectEqualStrings("Usage: test\n\nAfter help\n", help(a, &cmd));
}

test "hidden_arg_with_possible_value_with_help" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").disableVersionFlag(true)
        .arg(Arg.new("pos").hide(true).action(.set).possibleValues(&.{
        .{ .name = "fast" },
        .{ .name = "slow", .help = "not as fast" },
    }));
    try testing.expectEqualStrings(
        "Usage: ctest\n\n" ++
            "Options:\n" ++
            "  -h, --help  Print help\n",
        help(a, &cmd),
    );
}
