//! Ported subset of clap's tests/builder/help.rs — `help_template` substitution
//! + `override_usage`. Template tags: {name}/{bin}/{version}/{author*}/{about*}/
//! {usage-heading}/{usage}/{all-args}/{options}/{positionals}/{subcommands}/
//! {before-help}/{after-help}/{tab}. (Text-wrapping `term_width` cases deferred.)
//! https://github.com/clap-rs/clap/blob/master/tests/builder/help.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn helpText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, argv).err);
}

const FULL_TEMPLATE =
    "{before-help}{name} {version}\n" ++
    "{author-with-newline}{about-with-newline}\n" ++
    "{usage-heading} {usage}\n" ++
    "\n" ++
    "{all-args}{after-help}";

test "ripgrep_usage_using_templates" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ripgrep").version("0.5")
        .overrideUsage(
            "rg [OPTIONS] <pattern> [<path> ...]\n" ++
                "       rg [OPTIONS] [-e PATTERN | -f FILE ]... [<path> ...]\n" ++
                "       rg [OPTIONS] --files [<path> ...]\n" ++
                "       rg [OPTIONS] --type-list",
        )
        .helpTemplate("{bin} {version}\n\nUsage: {usage}\n\nOptions:\n{options}");
    try testing.expectEqualStrings(
        "ripgrep 0.5\n\n" ++
            "Usage: rg [OPTIONS] <pattern> [<path> ...]\n" ++
            "       rg [OPTIONS] [-e PATTERN | -f FILE ]... [<path> ...]\n" ++
            "       rg [OPTIONS] --files [<path> ...]\n" ++
            "       rg [OPTIONS] --type-list\n\n" ++
            "Options:\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "full_template_with_author_and_about" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("1.0").author("Foo").about("does stuff")
        .helpTemplate(FULL_TEMPLATE)
        .arg(Arg.fromUsage("-o --option <opt>", "an option"));
    try testing.expectEqualStrings(
        "ctest 1.0\n" ++
            "Foo\n" ++
            "does stuff\n\n" ++
            "Usage: ctest [OPTIONS]\n\n" ++
            "Options:\n" ++
            "  -o, --option <opt>  an option\n" ++
            "  -h, --help          Print help\n" ++
            "  -V, --version       Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "template_all_args_with_subcommands_and_positionals" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "prog").version("1.0").about("does stuff")
        .helpTemplate(FULL_TEMPLATE)
        .arg(Arg.new("input").help("the input"))
        .arg(Arg.fromUsage("-v --verbose", "be loud"))
        .subcommand(Command.init(a, "run").about("run it"));
    try testing.expectEqualStrings(
        "prog 1.0\n" ++
            "does stuff\n\n" ++
            "Usage: prog [OPTIONS] [input] [COMMAND]\n\n" ++
            "Commands:\n" ++
            "  run   run it\n" ++
            "  help  Print this message or the help of the given subcommand(s)\n\n" ++
            "Arguments:\n" ++
            "  [input]  the input\n\n" ++
            "Options:\n" ++
            "  -v, --verbose  be loud\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "dont_strip_padding_issue_5083" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").helpTemplate("{subcommands}")
        .subcommand(Command.init(a, "one"))
        .subcommand(Command.init(a, "two"))
        .subcommand(Command.init(a, "three"));
    try testing.expectEqualStrings(
        "  one    \n" ++
            "  two    \n" ++
            "  three  \n" ++
            "  help   Print this message or the help of the given subcommand(s)\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}
