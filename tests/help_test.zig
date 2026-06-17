const std = @import("std");
const clap = @import("clap");
const fixture = @import("fixture.zig");

const testing = std.testing;

test "help: root" {
    var f = fixture.Fixture.init();
    defer f.deinit();
    try testing.expectEqualStrings(fixture.root_help, clap.renderHelp(f.allocator(), &f.root));
}

test "help: add subcommand" {
    var f = fixture.Fixture.init();
    defer f.deinit();
    try testing.expectEqualStrings(fixture.add_help, clap.renderHelp(f.allocator(), f.root.findSubcommand("add").?));
}

test "help: diff subcommand" {
    var f = fixture.Fixture.init();
    defer f.deinit();
    try testing.expectEqualStrings(fixture.diff_help, clap.renderHelp(f.allocator(), f.root.findSubcommand("diff").?));
}

test "help: stash subcommands (non-flatten)" {
    var f = fixture.Fixture.init();
    defer f.deinit();
    const stash = f.root.findSubcommand("stash").?;
    try testing.expectEqualStrings(fixture.stash_push_help, clap.renderHelp(f.allocator(), stash.findSubcommand("push").?));
    try testing.expectEqualStrings(fixture.stash_pop_help, clap.renderHelp(f.allocator(), stash.findSubcommand("pop").?));
}

test "help: stash flatten_help" {
    var f = fixture.Fixture.init();
    defer f.deinit();
    try testing.expectEqualStrings(fixture.stash_flatten_help, clap.renderHelp(f.allocator(), f.root.findSubcommand("stash").?));
}
