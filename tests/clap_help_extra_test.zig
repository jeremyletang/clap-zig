//! Ported from clap's tests/builder/help.rs — the "For more information, try
//! '...'" hint logic: auto help flag, user-defined Help-action flags (long/short),
//! the no-help-flag case (hint omitted), and the help-subcommand fallback.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/help.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn errText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, argv).err);
}

test "try_help_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("1.0");
    try testing.expectEqualStrings(
        "error: unexpected argument 'bar' found\n\nUsage: ctest\n\nFor more information, try '--help'.\n",
        errText(a, &cmd, &.{"bar"}),
    );
}

test "try_help_custom_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("1.0").disableHelpFlag(true)
        .arg(Arg.new("help").long("help").short('h').action(.help));
    try testing.expectEqualStrings(
        "error: unexpected argument 'bar' found\n\nUsage: ctest\n\nFor more information, try '--help'.\n",
        errText(a, &cmd, &.{"bar"}),
    );
}

test "try_help_custom_flag_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("1.0").disableHelpFlag(true)
        .arg(Arg.new("help").short('h').action(.help_short));
    try testing.expectEqualStrings(
        "error: unexpected argument 'bar' found\n\nUsage: ctest\n\nFor more information, try '-h'.\n",
        errText(a, &cmd, &.{"bar"}),
    );
}

test "try_help_custom_flag_long" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("1.0").disableHelpFlag(true)
        .arg(Arg.new("help").long("help").action(.help_short));
    try testing.expectEqualStrings(
        "error: unexpected argument 'bar' found\n\nUsage: ctest\n\nFor more information, try '--help'.\n",
        errText(a, &cmd, &.{"bar"}),
    );
}

test "try_help_custom_flag_no_action" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("1.0").disableHelpFlag(true)
        .arg(Arg.new("help").long("help").global(true));
    try testing.expectEqualStrings(
        "error: unexpected argument 'bar' found\n\nUsage: ctest\n\n",
        errText(a, &cmd, &.{"bar"}),
    );
}

test "try_help_subcommand_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("1.0").subcommand(Command.init(a, "foo"));
    try testing.expectEqualStrings(
        "error: unrecognized subcommand 'bar'\n\nUsage: ctest [COMMAND]\n\nFor more information, try '--help'.\n",
        errText(a, &cmd, &.{"bar"}),
    );
}

test "try_help_subcommand_custom_flag" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("1.0").disableHelpFlag(true)
        .arg(Arg.new("help").long("help").short('h').action(.help).global(true))
        .subcommand(Command.init(a, "foo"));
    try testing.expectEqualStrings(
        "error: unrecognized subcommand 'bar'\n\nUsage: ctest [COMMAND]\n\nFor more information, try '--help'.\n",
        errText(a, &cmd, &.{"bar"}),
    );
}

test "try_help_subcommand_custom_flag_no_action" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("1.0").disableHelpFlag(true)
        .arg(Arg.new("help").long("help").global(true))
        .subcommand(Command.init(a, "foo"));
    try testing.expectEqualStrings(
        "error: unrecognized subcommand 'bar'\n\nUsage: ctest [COMMAND]\n\nFor more information, try 'help'.\n",
        errText(a, &cmd, &.{"bar"}),
    );
}
