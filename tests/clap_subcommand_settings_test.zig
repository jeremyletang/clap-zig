//! Ported from clap's tests/builder/subcommands.rs — `subcommand_value_name` and
//! `subcommand_help_heading` rename the usage placeholder and the help section.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/subcommands.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Command = clap.Command;

test "subcommand_placeholder_test" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog")
        .subcommand(Command.init(a, "subcommand"))
        .subcommandValueName("TEST_PLACEHOLDER")
        .subcommandHelpHeading("TEST_HEADER");
    cmd.buildTree();
    const help = clap.renderHelp(a, &cmd);
    try testing.expect(std.mem.indexOf(u8, help, "Usage: myprog [TEST_PLACEHOLDER]") != null);
    try testing.expect(std.mem.indexOf(u8, help, "TEST_HEADER:") != null);
}
