//! Ported subset of clap's tests/builder/help.rs — self-contained cases (no
//! complex_app, help_template, author, global args, or wrapping).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/help.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;
const range = clap.ValueRange;

fn run(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) clap.Outcome {
    cmd.buildTree();
    return clap.getMatches(a, cmd, argv);
}

// setup() in clap: Command::new("test").author(..).about(..).version(..)
// We omit author (a help-output-only field we don't render); these assert the
// error KIND, which author doesn't affect.
fn setup(a: std.mem.Allocator) Command {
    return Command.init(a, "test").about("tests stuff").version("1.3");
}

test "help_short / help_long -> DisplayHelp" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = setup(a);
    try testing.expectEqual(clap.ErrorKind.display_help, run(a, &c1, &.{"-h"}).err.kind);
    var c2 = setup(a);
    try testing.expectEqual(clap.ErrorKind.display_help, run(a, &c2, &.{"--help"}).err.kind);
}

test "help_no_subcommand -> UnknownArgument (no help subcommand without subcommands)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = setup(a);
    try testing.expectEqual(clap.ErrorKind.unknown_argument, run(a, &cmd, &.{"help"}).err.kind);
}

test "help_subcommand -> DisplayHelp" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = setup(a).subcommand(Command.init(a, "test").about("tests things")
        .arg(Arg.fromUsage("-v --verbose", "with verbosity")));
    try testing.expectEqual(clap.ErrorKind.display_help, run(a, &cmd, &.{"help"}).err.kind);
}

test "req_last_arg_usage" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "example").version("1.0")
        .arg(Arg.new("FIRST").help("First").numArgs(range.atLeast(1)).required(true))
        .arg(Arg.new("SECOND").help("Second").numArgs(range.atLeast(1)).required(true).last(true));
    cmd.buildTree();
    try testing.expectEqualStrings(
        "Usage: example <FIRST>... -- <SECOND>...\n" ++
            "\n" ++
            "Arguments:\n" ++
            "  <FIRST>...   First\n" ++
            "  <SECOND>...  Second\n" ++
            "\n" ++
            "Options:\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n",
        clap.renderHelp(a, &cmd),
    );
}

test "last_arg_mult_usage (optional last)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "last").version("0.1")
        .arg(Arg.new("TARGET").required(true).help("some"))
        .arg(Arg.new("CORPUS").help("some"))
        .arg(Arg.new("ARGS").action(.set).numArgs(range.atLeast(1)).last(true).help("some"));
    cmd.buildTree();
    try testing.expectEqualStrings(
        "Usage: last <TARGET> [CORPUS] [-- <ARGS>...]\n" ++
            "\n" ++
            "Arguments:\n" ++
            "  <TARGET>   some\n" ++
            "  [CORPUS]   some\n" ++
            "  [ARGS]...  some\n" ++
            "\n" ++
            "Options:\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n",
        clap.renderHelp(a, &cmd),
    );
}

test "last_arg_mult_usage_req (required last)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "last").version("0.1")
        .arg(Arg.new("TARGET").required(true).help("some"))
        .arg(Arg.new("CORPUS").help("some"))
        .arg(Arg.new("ARGS").action(.set).numArgs(range.atLeast(1)).last(true).required(true).help("some"));
    cmd.buildTree();
    try testing.expectEqualStrings(
        "Usage: last <TARGET> [CORPUS] -- <ARGS>...\n" ++
            "\n" ++
            "Arguments:\n" ++
            "  <TARGET>   some\n" ++
            "  [CORPUS]   some\n" ++
            "  <ARGS>...  some\n" ++
            "\n" ++
            "Options:\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n",
        clap.renderHelp(a, &cmd),
    );
}

test "issue_1487 (required group of positionals in usage)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    // clap derives the displayed name from argv[0] ("ctest"); we name it directly.
    var cmd = Command.init(a, "ctest")
        .arg(Arg.new("arg1").group("group1"))
        .arg(Arg.new("arg2").group("group1"))
        .group(clap.ArgGroup.new("group1").args(&.{ "arg1", "arg2" }).required(true));
    cmd.buildTree();
    try testing.expectEqualStrings(
        "Usage: ctest <arg1|arg2>\n" ++
            "\n" ++
            "Arguments:\n" ++
            "  [arg1]  \n" ++
            "  [arg2]  \n" ++
            "\n" ++
            "Options:\n" ++
            "  -h, --help  Print help\n",
        clap.renderHelp(a, &cmd),
    );
}

test "option_usage_order (definition order preserved)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "order")
        .arg(Arg.new("a").short('a').action(.set_true))
        .arg(Arg.new("B").short('B').action(.set_true))
        .arg(Arg.new("b").short('b').action(.set_true))
        .arg(Arg.new("save").short('s').action(.set_true))
        .arg(Arg.new("select_file").long("select_file").action(.set_true))
        .arg(Arg.new("select_folder").long("select_folder").action(.set_true))
        .arg(Arg.new("x").short('x').action(.set_true));
    cmd.buildTree();
    try testing.expectEqualStrings(
        "Usage: order [OPTIONS]\n" ++
            "\n" ++
            "Options:\n" ++
            "  -a                   \n" ++
            "  -B                   \n" ++
            "  -b                   \n" ++
            "  -s                   \n" ++
            "      --select_file    \n" ++
            "      --select_folder  \n" ++
            "  -x                   \n" ++
            "  -h, --help           Print help\n",
        clap.renderHelp(a, &cmd),
    );
}
