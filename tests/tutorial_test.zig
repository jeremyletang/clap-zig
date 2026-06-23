const std = @import("std");
const testing = std.testing;

const flag_bool = @import("flag_bool");
const flag_count = @import("flag_count");
const option = @import("option");
const default_values = @import("default_values");
const required = @import("required");
const possible = @import("possible");
const enum_ex = @import("enum_ex");
const parse = @import("parse");
const validate = @import("validate");
const relations = @import("relations");

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
    try expectRun(flag_bool.run, &.{ "--verbose", "--verbose" }, 2, "error: the argument '--verbose' cannot be used multiple times\n" ++
        "\n" ++
        "Usage: 03_01_flag_bool [OPTIONS]\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
    try expectRun(flag_bool.run, &.{"--help"}, 0, "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
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
    try expectRun(flag_count.run, &.{"--help"}, 0, "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
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
    try expectRun(option.run, &.{"--help"}, 0, "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
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
    try expectRun(default_values.run, &.{"--help"}, 0, "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
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
    try expectRun(required.run, &.{}, 2, "error: the following required arguments were not provided:\n" ++
        "  <name>\n" ++
        "\n" ++
        "Usage: 03_06_required <name>\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
}

const relations_help =
    "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
    "\n" ++
    "Usage: 04_03_relations [OPTIONS] <--set-ver <VER>|--major|--minor|--patch> [INPUT_FILE]\n" ++
    "\n" ++
    "Arguments:\n" ++
    "  [INPUT_FILE]  some regular input\n" ++
    "\n" ++
    "Options:\n" ++
    "      --set-ver <VER>      set version manually\n" ++
    "      --major              auto inc major\n" ++
    "      --minor              auto inc minor\n" ++
    "      --patch              auto inc patch\n" ++
    "      --spec-in <SPEC_IN>  some special input argument\n" ++
    "  -c <CONFIG>              \n" ++
    "  -h, --help               Print help\n" ++
    "  -V, --version            Print version\n";

test "04_03_relations" {
    try expectRun(relations.run, &.{"--help"}, 0, relations_help);
    try expectRun(relations.run, &.{"--major"}, 0, "Version: 2.2.3\n");
    try expectRun(relations.run, &.{ "--major", "--minor" }, 2, "error: the argument '--major' cannot be used with '--minor'\n" ++
        "\n" ++
        "Usage: 04_03_relations <--set-ver <VER>|--major|--minor|--patch> [INPUT_FILE]\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
    try expectRun(relations.run, &.{}, 2, "error: the following required arguments were not provided:\n" ++
        "  <--set-ver <VER>|--major|--minor|--patch>\n" ++
        "\n" ++
        "Usage: 04_03_relations <--set-ver <VER>|--major|--minor|--patch> [INPUT_FILE]\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
    try expectRun(relations.run, &.{ "--major", "-c", "config.toml" }, 2, "error: the following required arguments were not provided:\n" ++
        "  <INPUT_FILE|--spec-in <SPEC_IN>>\n" ++
        "\n" ++
        "Usage: 04_03_relations -c <CONFIG> <--set-ver <VER>|--major|--minor|--patch> <INPUT_FILE|--spec-in <SPEC_IN>>\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
    try expectRun(relations.run, &.{ "--major", "-c", "config.toml", "--spec-in", "input.txt" }, 0, "Version: 2.2.3\n" ++
        "Doing work using input input.txt and config config.toml\n");
}

test "04_01_enum: run and invalid value" {
    try expectRun(enum_ex.run, &.{"fast"}, 0, "Hare\n");
    try expectRun(enum_ex.run, &.{"slow"}, 0, "Tortoise\n");
    try expectRun(enum_ex.run, &.{"medium"}, 2, "error: invalid value 'medium' for '<MODE>'\n" ++
        "  [possible values: fast, slow]\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
}

test "04_01_enum: short help (-h)" {
    try expectRun(enum_ex.run, &.{"-h"}, 0, "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
        "\n" ++
        "Usage: 04_01_enum <MODE>\n" ++
        "\n" ++
        "Arguments:\n" ++
        "  <MODE>  What mode to run the program in [possible values: fast, slow]\n" ++
        "\n" ++
        "Options:\n" ++
        "  -h, --help     Print help (see more with '--help')\n" ++
        "  -V, --version  Print version\n");
}

test "04_01_enum: long help (--help)" {
    try expectRun(enum_ex.run, &.{"--help"}, 0, "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
        "\n" ++
        "Usage: 04_01_enum <MODE>\n" ++
        "\n" ++
        "Arguments:\n" ++
        "  <MODE>\n" ++
        "          What mode to run the program in\n" ++
        "\n" ++
        "          Possible values:\n" ++
        "          - fast: Run swiftly\n" ++
        "          - slow: Crawl slowly but steadily\n" ++
        "\n" ++
        "Options:\n" ++
        "  -h, --help\n" ++
        "          Print help (see a summary with '-h')\n" ++
        "\n" ++
        "  -V, --version\n" ++
        "          Print version\n");
}

test "04_02_parse" {
    try expectRun(parse.run, &.{"22"}, 0, "PORT = 22\n");
    try expectRun(parse.run, &.{"foobar"}, 2, "error: invalid value 'foobar' for '<PORT>': invalid digit found in string\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
    try expectRun(parse.run, &.{"0"}, 2, "error: invalid value '0' for '<PORT>': 0 is not in 1..=65535\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
}

test "04_02_validate" {
    try expectRun(validate.run, &.{"22"}, 0, "PORT = 22\n");
    try expectRun(validate.run, &.{"foobar"}, 2, "error: invalid value 'foobar' for '<PORT>': `foobar` isn't a port number\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
    try expectRun(validate.run, &.{"0"}, 2, "error: invalid value '0' for '<PORT>': port not in range 1-65535\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
}

test "04_01_possible" {
    try expectRun(possible.run, &.{"fast"}, 0, "Hare\n");
    try expectRun(possible.run, &.{"slow"}, 0, "Tortoise\n");
    try expectRun(possible.run, &.{"medium"}, 2, "error: invalid value 'medium' for '<MODE>'\n" ++
        "  [possible values: fast, slow]\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
    try expectRun(possible.run, &.{"--help"}, 0, "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
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
