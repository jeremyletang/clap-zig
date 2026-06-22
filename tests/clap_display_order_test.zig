//! Ported subset of clap's tests/builder/derive_order.rs + display_order.rs —
//! `display_order` / `next_display_order` help sorting (default = definition
//! order; `next_display_order(None)` sorts alphabetically by flag/key).
//! https://github.com/clap-rs/clap/blob/master/tests/builder/derive_order.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn helpText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, argv).err);
}

fn flag(name: []const u8, h: []const u8) Arg {
    return Arg.new(name).long(name).help(h).action(.set_true);
}
fn opt(name: []const u8, h: []const u8) Arg {
    return Arg.new(name).long(name).action(.set).help(h);
}

test "derive_order (default = definition order)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.2")
        .arg(flag("flag_b", "first flag"))
        .arg(opt("option_b", "first option"))
        .arg(flag("flag_a", "second flag"))
        .arg(opt("option_a", "second option"));
    try testing.expectEqualStrings(
        "Usage: test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "      --flag_b               first flag\n" ++
            "      --option_b <option_b>  first option\n" ++
            "      --flag_a               second flag\n" ++
            "      --option_a <option_a>  second option\n" ++
            "  -h, --help                 Print help\n" ++
            "  -V, --version              Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "no_derive_order (next_display_order None = alphabetical)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.2").nextDisplayOrder(null)
        .arg(flag("flag_b", "first flag"))
        .arg(opt("option_b", "first option"))
        .arg(flag("flag_a", "second flag"))
        .arg(opt("option_a", "second option"));
    try testing.expectEqualStrings(
        "Usage: test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "      --flag_a               second flag\n" ++
            "      --flag_b               first flag\n" ++
            "  -h, --help                 Print help\n" ++
            "      --option_a <option_a>  second option\n" ++
            "      --option_b <option_b>  first option\n" ++
            "  -V, --version              Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "derive_order_next_order" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.2")
        .nextDisplayOrder(10000)
        .arg(flag("flag_a", "second flag"))
        .arg(opt("option_a", "second option"))
        .nextDisplayOrder(10)
        .arg(flag("flag_b", "first flag"))
        .arg(opt("option_b", "first option"));
    try testing.expectEqualStrings(
        "Usage: test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "      --flag_b               first flag\n" ++
            "      --option_b <option_b>  first option\n" ++
            "  -h, --help                 Print help\n" ++
            "  -V, --version              Print version\n" ++
            "      --flag_a               second flag\n" ++
            "      --option_a <option_a>  second option\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "derive_order_no_next_order" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.2").nextDisplayOrder(null)
        .arg(flag("flag_a", "first flag"))
        .arg(opt("option_a", "first option"))
        .arg(flag("flag_b", "second flag"))
        .arg(opt("option_b", "second option"));
    try testing.expectEqualStrings(
        "Usage: test [OPTIONS]\n\n" ++
            "Options:\n" ++
            "      --flag_a               first flag\n" ++
            "      --flag_b               second flag\n" ++
            "  -h, --help                 Print help\n" ++
            "      --option_a <option_a>  first option\n" ++
            "      --option_b <option_b>  second option\n" ++
            "  -V, --version              Print version\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}

test "very_large_display_order (subcommand)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .subcommand(Command.init(a, "sub").displayOrder(std.math.maxInt(usize)));
    try testing.expectEqualStrings(
        "Usage: test [COMMAND]\n\n" ++
            "Commands:\n" ++
            "  help  Print this message or the help of the given subcommand(s)\n" ++
            "  sub   \n\n" ++
            "Options:\n" ++
            "  -h, --help  Print help\n",
        helpText(a, &cmd, &.{"--help"}),
    );
}
