const std = @import("std");
const ep = @import("escaped_positional");

const testing = std.testing;

fn expectRun(argv: []const []const u8, expected_code: u8, expected_out: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var out: std.ArrayList(u8) = .empty;
    const code = ep.run(arena.allocator(), argv, &out);
    try testing.expectEqual(expected_code, code);
    try testing.expectEqualStrings(expected_out, out.items);
}

// Verified against clap's escaped-positional.md (rendering the real binary name):
// https://github.com/clap-rs/clap/blob/master/examples/escaped-positional.md

const help_text =
    "A simple to use, efficient, and full-featured Command Line Argument Parser\n" ++
    "\n" ++
    "Usage: escaped-positional [OPTIONS] [-- <SLOP>...]\n" ++
    "\n" ++
    "Arguments:\n" ++
    "  [SLOP]...  \n" ++
    "\n" ++
    "Options:\n" ++
    "  -f             \n" ++
    "  -p <PEAR>      \n" ++
    "  -h, --help     Print help\n" ++
    "  -V, --version  Print version\n";

test "escaped-positional: help" {
    try expectRun(&.{"--help"}, 0, help_text);
}

test "escaped-positional: baseline (no args)" {
    try expectRun(&.{}, 0, "-f used: false\n" ++
        "-p's value: (none)\n" ++
        "'slops' values: (none)\n");
}

test "escaped-positional: positional before -- is rejected" {
    try expectRun(&.{ "foo", "bar" }, 2, "error: unexpected argument 'foo' found\n" ++
        "\n" ++
        "Usage: escaped-positional [OPTIONS] [-- <SLOP>...]\n" ++
        "\n" ++
        "For more information, try '--help'.\n");
}

test "escaped-positional: flags then escaped slop" {
    try expectRun(&.{ "-f", "-p=bob", "--", "sloppy", "slop", "slop" }, 0, "-f used: true\n" ++
        "-p's value: bob\n" ++
        "'slops' values: sloppy, slop, slop\n");
}

test "escaped-positional: everything after -- passes through" {
    try expectRun(&.{ "--", "-f", "-p=bob", "sloppy", "slop", "slop" }, 0, "-f used: false\n" ++
        "-p's value: (none)\n" ++
        "'slops' values: -f, -p=bob, sloppy, slop, slop\n");
}
