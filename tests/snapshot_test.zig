const std = @import("std");
const git = @import("git");
const fixture = @import("fixture.zig");

const testing = std.testing;

/// Run the git example end-to-end and assert its combined output and exit code
/// match clap's git.md. (git.md shows `git[EXE]`; we render `git`. A `? failed`
/// marker in git.md means exit code 2.)
fn expectRun(argv: []const []const u8, expected_code: u8, expected_out: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var out: std.ArrayList(u8) = .empty;
    const code = git.run(a, argv, &out);
    try testing.expectEqual(expected_code, code);
    try testing.expectEqualStrings(expected_out, out.items);
}

test "snapshot: help and arg_required_else_help" {
    try expectRun(&.{}, 2, fixture.root_help); // bare `git` -> ? failed
    try expectRun(&.{"help"}, 0, fixture.root_help);
    try expectRun(&.{ "help", "add" }, 0, fixture.add_help);
    try expectRun(&.{"add"}, 2, fixture.add_help); // ? failed
}

test "snapshot: add" {
    try expectRun(&.{ "add", "Cargo.toml", "Cargo.lock" }, 0, "Adding [\"Cargo.toml\", \"Cargo.lock\"]\n");
}

test "snapshot: stash help variants" {
    try expectRun(&.{ "stash", "-h" }, 0, fixture.stash_flatten_help);
    try expectRun(&.{ "stash", "push", "-h" }, 0, fixture.stash_push_help);
    try expectRun(&.{ "stash", "pop", "-h" }, 0, fixture.stash_pop_help);
}

test "snapshot: stash run" {
    try expectRun(&.{ "stash", "-m", "Prototype" }, 0, "Pushing Some(\"Prototype\")\n");
    try expectRun(&.{ "stash", "pop" }, 0, "Popping None\n");
    try expectRun(&.{ "stash", "push", "-m", "Prototype" }, 0, "Pushing Some(\"Prototype\")\n");
}

test "snapshot: external subcommand" {
    try expectRun(&.{ "custom-tool", "arg1", "--foo", "bar" }, 0, "Calling out to \"custom-tool\" with [\"arg1\", \"--foo\", \"bar\"]\n");
}

test "snapshot: diff" {
    try expectRun(&.{"diff"}, 0, "Diffing stage..worktree  (color=auto)\n");
    try expectRun(&.{ "diff", "./src" }, 0, "Diffing stage..worktree ./src (color=auto)\n");
    try expectRun(&.{ "diff", "HEAD", "./src" }, 0, "Diffing HEAD..worktree ./src (color=auto)\n");
    try expectRun(&.{ "diff", "HEAD~~", "--", "HEAD" }, 0, "Diffing HEAD~~..worktree HEAD (color=auto)\n");
    try expectRun(&.{ "diff", "--color" }, 0, "Diffing stage..worktree  (color=always)\n");
    try expectRun(&.{ "diff", "--color=never" }, 0, "Diffing stage..worktree  (color=never)\n");
}

test "snapshot: diff --help" {
    try expectRun(&.{ "diff", "--help" }, 0, fixture.diff_help);
}
