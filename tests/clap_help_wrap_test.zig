//! Ported subset of clap's tests/builder/help.rs — `term_width` help wrapping
//! (word-wrap of the help column, continuation lines aligned under it).
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

fn wrapApp(a: std.mem.Allocator, width: usize) Command {
    return Command.init(a, "test").termWidth(width)
        .arg(Arg.new("all").short('a').long("all").action(.set_true)
            .help("Also do versioning for private crates (will not be published)"))
        .arg(Arg.new("exact").long("exact").action(.set_true)
            .help("Specify inter dependency version numbers exactly with `=`"))
        .arg(Arg.new("no_git_commit").long("no-git-commit").action(.set_true)
            .help("Do not commit version changes"))
        .arg(Arg.new("no_git_push").long("no-git-push").action(.set_true)
            .help("Do not push generated commit and tags to git remote"))
        .subcommand(Command.init(a, "sub1")
        .about("One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen"));
}

test "wrapped_help" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = wrapApp(a, 67);
    try testing.expectEqualStrings(
        "Usage: test [OPTIONS] [COMMAND]\n\n" ++
            "Commands:\n" ++
            "  sub1  One two three four five six seven eight nine ten eleven\n" ++
            "        twelve thirteen fourteen fifteen\n" ++
            "  help  Print this message or the help of the given subcommand(s)\n\n" ++
            "Options:\n" ++
            "  -a, --all            Also do versioning for private crates (will\n" ++
            "                       not be published)\n" ++
            "      --exact          Specify inter dependency version numbers\n" ++
            "                       exactly with `=`\n" ++
            "      --no-git-commit  Do not commit version changes\n" ++
            "      --no-git-push    Do not push generated commit and tags to git\n" ++
            "                       remote\n" ++
            "  -h, --help           Print help\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "unwrapped_help" {
    // clap renders width 68 identically to width 67 for this fixture.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = wrapApp(a, 68);
    try testing.expectEqualStrings(
        "Usage: test [OPTIONS] [COMMAND]\n\n" ++
            "Commands:\n" ++
            "  sub1  One two three four five six seven eight nine ten eleven\n" ++
            "        twelve thirteen fourteen fifteen\n" ++
            "  help  Print this message or the help of the given subcommand(s)\n\n" ++
            "Options:\n" ++
            "  -a, --all            Also do versioning for private crates (will\n" ++
            "                       not be published)\n" ++
            "      --exact          Specify inter dependency version numbers\n" ++
            "                       exactly with `=`\n" ++
            "      --no-git-commit  Do not commit version changes\n" ++
            "      --no-git-push    Do not push generated commit and tags to git\n" ++
            "                       remote\n" ++
            "  -h, --help           Print help\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "no_wrap_default_help" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ctest").version("1.0").termWidth(0);
    try testing.expectEqualStrings(
        "Usage: ctest\n\n" ++
            "Options:\n" ++
            "  -h, --help     Print help\n" ++
            "  -V, --version  Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}
