//! Ported from clap's tests/builder/app_settings.rs — arg_required_else_help,
//! subcommand_required, subcommand_negates_reqs, disable_help_subcommand, and
//! global-value propagation down to subcommands.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/app_settings.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const HelpOnMissing = clap.ErrorKind.display_help_on_missing_argument_or_subcommand;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

test "arg_required_else_help" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "arg_required").argRequiredElseHelp(true).arg(Arg.new("test"));
    try testing.expectEqual(HelpOnMissing, run(a, &cmd, &.{}).err.kind);
}

test "arg_required_else_help_with_default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "arg_required").argRequiredElseHelp(true)
        .arg(Arg.new("input").long("input").action(.set).defaultValue("-"));
    try testing.expectEqual(HelpOnMissing, run(a, &cmd, &.{}).err.kind);
}

test "arg_required_else_help_over_req_arg" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "arg_required").argRequiredElseHelp(true).arg(Arg.new("test").required(true));
    try testing.expectEqual(HelpOnMissing, run(a, &cmd, &.{}).err.kind);
}

test "arg_required_else_help_over_req_subcommand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "sub_required").argRequiredElseHelp(true).subcommandRequired(true)
        .subcommand(Command.init(a, "sub1"));
    try testing.expectEqual(HelpOnMissing, run(a, &cmd, &.{}).err.kind);
}

test "arg_required_else_help_error_message" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").argRequiredElseHelp(true).version("1.0")
        .arg(Arg.new("info").short('i').long("info").action(.set_true).help("Provides more info"));
    try testing.expectEqualStrings(
        "Usage: test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -i, --info     Provides more info\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n",
        clap.renderError(a, run(a, &cmd, &.{}).err),
    );
}

test "sub_command_required" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "sc_required").subcommandRequired(true).subcommand(Command.init(a, "sub1"));
    try testing.expectEqual(clap.ErrorKind.missing_subcommand, run(a, &cmd, &.{}).err.kind);
}

test "sub_command_required_error" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "sc_required").subcommandRequired(true).subcommand(Command.init(a, "sub1"));
    try testing.expectEqualStrings(
        "error: 'sc_required' requires a subcommand but one was not provided\n" ++
            "  [subcommands: sub1, help]\n\n" ++
            "Usage: sc_required <COMMAND>\n\n" ++
            "For more information, try '--help'.\n",
        clap.renderError(a, run(a, &cmd, &.{}).err),
    );
}

test "sub_command_negate_required" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "sub_command_negate").subcommandNegatesReqs(true)
        .arg(Arg.new("test").required(true)).subcommand(Command.init(a, "sub1"));
    try testing.expectEqualStrings("sub1", run(a, &cmd, &.{"sub1"}).matches.subcommand().?.name);
}

test "sub_command_negate_required_2" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "sub_command_negate").subcommandNegatesReqs(true)
        .arg(Arg.new("test").required(true)).subcommand(Command.init(a, "sub1"));
    try testing.expectEqual(clap.ErrorKind.missing_required_argument, run(a, &cmd, &.{}).err.kind);
}

test "disable_help_subcommand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "disablehelp").disableHelpSubcommand(true).subcommand(Command.init(a, "sub1"));
    try testing.expectEqual(clap.ErrorKind.invalid_subcommand, run(a, &cmd, &.{"help"}).err.kind);
}

test "propagate_vals_down" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog")
        .arg(Arg.new("cmd").global(true))
        .subcommand(Command.init(a, "foo"));
    const m = run(a, &cmd, &.{ "set", "foo" }).matches;
    try testing.expectEqualStrings("set", m.getOne([]const u8, "cmd").?);
    try testing.expectEqualStrings("set", m.subcommand().?.matches.getOne([]const u8, "cmd").?);
}
