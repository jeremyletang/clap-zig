const std = @import("std");
const testing = std.testing;

const flag_bool = @import("flag_bool");
const flag_count = @import("flag_count");
const option = @import("option");
const default_values = @import("default_values");
const required = @import("required");
const possible = @import("possible");

const RunFn = *const fn (std.mem.Allocator, []const []const u8, *std.ArrayList(u8)) u8;

fn expectRun(runFn: RunFn, argv: []const []const u8, code: u8, expected: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var out: std.ArrayList(u8) = .empty;
    try testing.expectEqual(code, runFn(arena.allocator(), argv, &out));
    try testing.expectEqualStrings(expected, out.items);
}

// Help/usage/error blocks are byte-exact vs clap's tutorial_builder/*.md (rendering
// the real binary name); the program's own result lines are idiomatic Zig.
// https://github.com/clap-rs/clap/tree/master/examples/tutorial_builder

test "03_01_flag_bool" {
    try expectRun(flag_bool.run, &.{}, 0, "verbose: false\n");
    try expectRun(flag_bool.run, &.{"--verbose"}, 0, "verbose: true\n");
    try expectRun(flag_bool.run, &.{ "--verbose", "--verbose" }, 2,
        "error: the argument '--verbose' cannot be used multiple times\n" ++
        "\n" ++
        "Usage: 03_01_flag_bool [OPTIONS]\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
    try expectRun(flag_bool.run, &.{"--help"}, 0,
        "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
        "\n" ++
        "Usage: 03_01_flag_bool [OPTIONS]\n" ++
        "\n" ++
        "Options:\n" ++
        "  -v, --verbose  \n" ++
        "  -h, --help     Print help\n" ++
        "  -V, --version  Print version\n");
}

test "03_01_flag_count" {
    try expectRun(flag_count.run, &.{}, 0, "verbose: 0\n");
    try expectRun(flag_count.run, &.{"--verbose"}, 0, "verbose: 1\n");
    try expectRun(flag_count.run, &.{ "--verbose", "--verbose" }, 0, "verbose: 2\n");
    try expectRun(flag_count.run, &.{"--help"}, 0,
        "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
        "\n" ++
        "Usage: 03_01_flag_count [OPTIONS]\n" ++
        "\n" ++
        "Options:\n" ++
        "  -v, --verbose...  \n" ++
        "  -h, --help        Print help\n" ++
        "  -V, --version     Print version\n");
}

test "03_02_option" {
    try expectRun(option.run, &.{}, 0, "name: (none)\n");
    try expectRun(option.run, &.{ "--name", "bob" }, 0, "name: bob\n");
    try expectRun(option.run, &.{"--name=bob"}, 0, "name: bob\n");
    try expectRun(option.run, &.{ "-n", "bob" }, 0, "name: bob\n");
    try expectRun(option.run, &.{"-nbob"}, 0, "name: bob\n");
    try expectRun(option.run, &.{"--help"}, 0,
        "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
        "\n" ++
        "Usage: 03_02_option [OPTIONS]\n" ++
        "\n" ++
        "Options:\n" ++
        "  -n, --name <name>  \n" ++
        "  -h, --help         Print help\n" ++
        "  -V, --version      Print version\n");
}

test "03_05_default_values" {
    try expectRun(default_values.run, &.{}, 0, "port: 2020\n");
    try expectRun(default_values.run, &.{"22"}, 0, "port: 22\n");
    try expectRun(default_values.run, &.{"--help"}, 0,
        "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
        "\n" ++
        "Usage: 03_05_default_values [PORT]\n" ++
        "\n" ++
        "Arguments:\n" ++
        "  [PORT]  [default: 2020]\n" ++
        "\n" ++
        "Options:\n" ++
        "  -h, --help     Print help\n" ++
        "  -V, --version  Print version\n");
}

test "03_06_required" {
    try expectRun(required.run, &.{"bob"}, 0, "name: bob\n");
    try expectRun(required.run, &.{}, 2,
        "error: the following required arguments were not provided:\n" ++
        "  <name>\n" ++
        "\n" ++
        "Usage: 03_06_required <name>\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
}

test "04_01_possible" {
    try expectRun(possible.run, &.{"fast"}, 0, "Hare\n");
    try expectRun(possible.run, &.{"slow"}, 0, "Tortoise\n");
    try expectRun(possible.run, &.{"medium"}, 2,
        "error: invalid value 'medium' for '<MODE>'\n" ++
        "  [possible values: fast, slow]\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
    try expectRun(possible.run, &.{"--help"}, 0,
        "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
        "\n" ++
        "Usage: 04_01_possible <MODE>\n" ++
        "\n" ++
        "Arguments:\n" ++
        "  <MODE>  What mode to run the program in [possible values: fast, slow]\n" ++
        "\n" ++
        "Options:\n" ++
        "  -h, --help     Print help\n" ++
        "  -V, --version  Print version\n");
}
