//! Ported from clap's tests/builder/{opts,subcommands,possible_values}.rs +
//! the suggestions feature unit tests — "did you mean" hints for mistyped long
//! flags, subcommands, and possible values (Jaro similarity, `> 0.7` threshold).
//! https://github.com/clap-rs/clap/blob/master/clap_builder/src/parser/features/suggestions.rs

const std = @import("std");
const clap = @import("clap");
const fixture = @import("complex_app.zig");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn errText(a: std.mem.Allocator, cmd: *Command, argv: []const []const u8) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, argv).err);
}

// ----- did_you_mean (Jaro) unit tests -----

fn dym(a: std.mem.Allocator, v: []const u8, possible: []const []const u8) [][]const u8 {
    return clap.didYouMean(a, v, possible);
}

test "did_you_mean missing_letter" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const got = dym(arena.allocator(), "tst", &.{ "test", "possible", "values" });
    try testing.expectEqual(@as(usize, 1), got.len);
    try testing.expectEqualStrings("test", got[0]);
}

test "did_you_mean ambiguous" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const got = dym(arena.allocator(), "te", &.{ "test", "temp", "possible", "values" });
    try testing.expectEqual(@as(usize, 2), got.len);
    try testing.expectEqualStrings("test", got[0]);
    try testing.expectEqualStrings("temp", got[1]);
}

test "did_you_mean unrelated" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const got = dym(arena.allocator(), "hahaahahah", &.{ "test", "possible", "values" });
    try testing.expectEqual(@as(usize, 0), got.len);
}

test "did_you_mean best_fit" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const got = dym(arena.allocator(), "alignmentScorr", &.{ "test", "possible", "values", "alignmentStart", "alignmentScore" });
    try testing.expectEqual(@as(usize, 2), got.len);
    try testing.expectEqualStrings("alignmentStart", got[0]);
    try testing.expectEqualStrings("alignmentScore", got[1]);
}

test "did_you_mean best_fit_long_common_prefix_issue_4660" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const got = dym(arena.allocator(), "alignmentScorr", &.{ "alignmentScore", "alignmentStart" });
    try testing.expectEqual(@as(usize, 2), got.len);
    try testing.expectEqualStrings("alignmentStart", got[0]);
    try testing.expectEqualStrings("alignmentScore", got[1]);
}

// ----- argument suggestions -----

test "did_you_mean (argument, complex_app)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = fixture.complexApp(a);
    try testing.expectEqualStrings(
        "error: unexpected argument '--optio' found\n\n" ++
            "  tip: a similar argument exists: '--option'\n\n" ++
            "Usage: clap-test --option <opt>... [positional] [positional2] [positional3]...\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{"--optio=foo"}),
    );
}

test "issue_1073_suboptimal_flag_suggestion" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "ripgrep-616")
        .arg(Arg.new("files-with-matches").long("files-with-matches").action(.set_true))
        .arg(Arg.new("files-without-match").long("files-without-match").action(.set_true));
    try testing.expectEqualStrings(
        "error: unexpected argument '--files-without-matches' found\n\n" ++
            "  tip: a similar argument exists: '--files-without-match'\n\n" ++
            "Usage: ripgrep-616 --files-without-match\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{"--files-without-matches"}),
    );
}

// ----- subcommand suggestions -----

test "subcmd_did_you_mean_output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "dym").subcommand(Command.init(a, "subcmd"));
    try testing.expectEqualStrings(
        "error: unrecognized subcommand 'subcm'\n\n" ++
            "  tip: a similar subcommand exists: 'subcmd'\n\n" ++
            "Usage: dym [COMMAND]\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{"subcm"}),
    );
}

test "subcmd_did_you_mean_output_ambiguous" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "dym")
        .subcommand(Command.init(a, "test"))
        .subcommand(Command.init(a, "temp"));
    try testing.expectEqualStrings(
        "error: unrecognized subcommand 'te'\n\n" ++
            "  tip: some similar subcommands exist: 'test', 'temp'\n\n" ++
            "Usage: dym [COMMAND]\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{"te"}),
    );
}

// ----- possible-value suggestions -----

test "possible_values_output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.new("option").short('O').action(.set)
        .valueParser(&.{ "slow", "fast", "ludicrous speed" }));
    try testing.expectEqualStrings(
        "error: invalid value 'slo' for '-O <option>'\n" ++
            "  [possible values: slow, fast, \"ludicrous speed\"]\n\n" ++
            "  tip: a similar value exists: 'slow'\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{ "-O", "slo" }),
    );
}

test "escaped_possible_values_output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test")
        .arg(Arg.new("option").short('O').action(.set)
        .valueParser(&.{ "slow", "fast", "ludicrous speed" }));
    try testing.expectEqualStrings(
        "error: invalid value 'ludicrous' for '-O <option>'\n" ++
            "  [possible values: slow, fast, \"ludicrous speed\"]\n\n" ++
            "  tip: a similar value exists: 'ludicrous speed'\n\n" ++
            "For more information, try '--help'.\n",
        errText(a, &cmd, &.{ "-O", "ludicrous" }),
    );
}
