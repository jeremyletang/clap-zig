//! Ported from clap's tests/builder/help.rs — `flatten_help`: the parent help
//! lists every subcommand's usage and renders a section per subcommand. (The
//! long-layout, recursive, and hidden-subcommand variants are out of scope.)
//! https://github.com/clap-rs/clap/blob/master/tests/builder/help.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn help(a: std.mem.Allocator, cmd: *Command) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, &.{"-h"}).err);
}

fn opt(id: []const u8) Arg {
    return Arg.new(id).long(id).action(.set);
}

test "flatten_basic" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "parent").flattenHelp(true).about("parent command")
        .arg(Arg.new("parent").long("parent").action(.set))
        .subcommand(Command.init(a, "test").about("test command").arg(Arg.new("child").long("child").action(.set)));
    try testing.expectEqualStrings(
        "parent command\n\n" ++
            "Usage: parent [OPTIONS]\n" ++
            "       parent test [OPTIONS]\n" ++
            "       parent help [COMMAND]...\n\n" ++
            "Options:\n" ++
            "      --parent <parent>  \n" ++
            "  -h, --help             Print help\n\n" ++
            "parent test:\n" ++
            "test command\n" ++
            "      --child <child>  \n" ++
            "  -h, --help           Print help\n\n" ++
            "parent help:\n" ++
            "Print this message or the help of the given subcommand(s)\n" ++
            "  [COMMAND]...  Print help for the subcommand(s)\n",
        help(a, &cmd),
    );
}

test "flatten_without_subcommands" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "parent").flattenHelp(true).about("parent command")
        .arg(Arg.new("parent").long("parent").action(.set));
    try testing.expectEqualStrings(
        "parent command\n\n" ++
            "Usage: parent [OPTIONS]\n\n" ++
            "Options:\n" ++
            "      --parent <parent>  \n" ++
            "  -h, --help             Print help\n",
        help(a, &cmd),
    );
}

test "flatten_with_subcommand_required" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "parent").flattenHelp(true).about("parent command").subcommandRequired(true)
        .arg(Arg.new("parent").long("parent").action(.set))
        .subcommand(Command.init(a, "test").about("test command").arg(Arg.new("child").long("child").action(.set)));
    try testing.expectEqualStrings(
        "parent command\n\n" ++
            "Usage: parent test [OPTIONS]\n" ++
            "       parent help [COMMAND]...\n\n" ++
            "Options:\n" ++
            "      --parent <parent>  \n" ++
            "  -h, --help             Print help\n\n" ++
            "parent test:\n" ++
            "test command\n" ++
            "      --child <child>  \n" ++
            "  -h, --help           Print help\n\n" ++
            "parent help:\n" ++
            "Print this message or the help of the given subcommand(s)\n" ++
            "  [COMMAND]...  Print help for the subcommand(s)\n",
        help(a, &cmd),
    );
}

test "flatten_with_global" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "parent").flattenHelp(true).about("parent command")
        .arg(Arg.new("parent").long("parent").action(.set).global(true))
        .subcommand(Command.init(a, "test").about("test command").arg(Arg.new("child").long("child").action(.set)));
    try testing.expectEqualStrings(
        "parent command\n\n" ++
            "Usage: parent [OPTIONS]\n" ++
            "       parent test [OPTIONS]\n" ++
            "       parent help [COMMAND]...\n\n" ++
            "Options:\n" ++
            "      --parent <parent>  \n" ++
            "  -h, --help             Print help\n\n" ++
            "parent test:\n" ++
            "test command\n" ++
            "      --child <child>  \n" ++
            "  -h, --help           Print help\n\n" ++
            "parent help:\n" ++
            "Print this message or the help of the given subcommand(s)\n" ++
            "  [COMMAND]...  Print help for the subcommand(s)\n",
        help(a, &cmd),
    );
}

test "flatten_with_external_subcommand" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "parent").flattenHelp(true).about("parent command").allowExternalSubcommands(true)
        .arg(Arg.new("parent").long("parent").action(.set))
        .subcommand(Command.init(a, "test").about("test command").arg(Arg.new("child").long("child").action(.set)));
    try testing.expectEqualStrings(
        "parent command\n\n" ++
            "Usage: parent [OPTIONS]\n" ++
            "       parent test [OPTIONS]\n" ++
            "       parent help [COMMAND]...\n\n" ++
            "Options:\n" ++
            "      --parent <parent>  \n" ++
            "  -h, --help             Print help\n\n" ++
            "parent test:\n" ++
            "test command\n" ++
            "      --child <child>  \n" ++
            "  -h, --help           Print help\n\n" ++
            "parent help:\n" ++
            "Print this message or the help of the given subcommand(s)\n" ++
            "  [COMMAND]...  Print help for the subcommand(s)\n",
        help(a, &cmd),
    );
}

test "flatten_with_args_conflicts_with_subcommands" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "parent").flattenHelp(true).about("parent command")
        .subcommandRequired(true).argsConflictsWithSubcommands(true)
        .arg(Arg.new("parent").long("parent").action(.set))
        .subcommand(Command.init(a, "test").about("test command").arg(Arg.new("child").long("child").action(.set)));
    try testing.expectEqualStrings(
        "parent command\n\n" ++
            "Usage: parent [OPTIONS]\n" ++
            "       parent test [OPTIONS]\n" ++
            "       parent help [COMMAND]...\n\n" ++
            "Options:\n" ++
            "      --parent <parent>  \n" ++
            "  -h, --help             Print help\n\n" ++
            "parent test:\n" ++
            "test command\n" ++
            "      --child <child>  \n" ++
            "  -h, --help           Print help\n\n" ++
            "parent help:\n" ++
            "Print this message or the help of the given subcommand(s)\n" ++
            "  [COMMAND]...  Print help for the subcommand(s)\n",
        help(a, &cmd),
    );
}

test "flatten_not_recursive" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "parent").flattenHelp(true).about("parent command")
        .arg(Arg.new("parent").long("parent").action(.set))
        .subcommand(Command.init(a, "child1").about("child1 command").arg(Arg.new("child").long("child1").action(.set))
            .subcommand(Command.init(a, "grandchild1").about("grandchild1 command").arg(Arg.new("grandchild").long("grandchild1").action(.set)))
            .subcommand(Command.init(a, "grandchild2").about("grandchild2 command").arg(Arg.new("grandchild").long("grandchild2").action(.set)))
            .subcommand(Command.init(a, "grandchild3").about("grandchild3 command").arg(Arg.new("grandchild").long("grandchild3").action(.set))))
        .subcommand(Command.init(a, "child2").about("child2 command").arg(Arg.new("child").long("child2").action(.set)))
        .subcommand(Command.init(a, "child3").about("child3 command").arg(Arg.new("child").long("child3").action(.set)));
    try testing.expectEqualStrings(
        "parent command\n\n" ++
            "Usage: parent [OPTIONS]\n" ++
            "       parent child1 [OPTIONS] [COMMAND]\n" ++
            "       parent child2 [OPTIONS]\n" ++
            "       parent child3 [OPTIONS]\n" ++
            "       parent help [COMMAND]...\n\n" ++
            "Options:\n" ++
            "      --parent <parent>  \n" ++
            "  -h, --help             Print help\n\n" ++
            "parent child1:\n" ++
            "child1 command\n" ++
            "      --child1 <child>  \n" ++
            "  -h, --help            Print help\n\n" ++
            "parent child2:\n" ++
            "child2 command\n" ++
            "      --child2 <child>  \n" ++
            "  -h, --help            Print help\n\n" ++
            "parent child3:\n" ++
            "child3 command\n" ++
            "      --child3 <child>  \n" ++
            "  -h, --help            Print help\n\n" ++
            "parent help:\n" ++
            "Print this message or the help of the given subcommand(s)\n" ++
            "  [COMMAND]...  Print help for the subcommand(s)\n",
        help(a, &cmd),
    );
}
