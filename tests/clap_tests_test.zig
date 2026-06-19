//! Ported subset of clap's tests/builder/tests.rs — the complex_app parse matrix.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/tests.rs

const std = @import("std");
const clap = @import("clap");
const fixture = @import("complex_app.zig");

const testing = std.testing;

fn check(argv: []const []const u8, expected: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = fixture.complexApp(a);
    cmd.buildTree();
    const m = clap.getMatches(a, &cmd, argv).matches;
    try testing.expectEqualStrings(expected, fixture.checkComplex(a, m));
}

const FOP =
    "flag present 1 times\noption present with value: some\nAn option: some\n" ++
    "positional present with value: value\nflag2 NOT present\n" ++
    "option2 maybe present with value of: Nothing\npositional2 maybe present with value of: Nothing\n" ++
    "option3 NOT present\npositional3 NOT present\noption present with value: some\nAn option: some\n" ++
    "positional present with value: value\nsubcmd NOT present\n";

const F2OP =
    "flag present 2 times\noption present with value: some\nAn option: some\n" ++
    "positional present with value: value\nflag2 NOT present\n" ++
    "option2 maybe present with value of: Nothing\npositional2 maybe present with value of: Nothing\n" ++
    "option3 NOT present\npositional3 NOT present\noption present with value: some\nAn option: some\n" ++
    "positional present with value: value\nsubcmd NOT present\n";

const O2P =
    "flag NOT present\noption present with value: some\nAn option: some\nAn option: other\n" ++
    "positional present with value: value\nflag2 NOT present\n" ++
    "option2 maybe present with value of: Nothing\npositional2 maybe present with value of: Nothing\n" ++
    "option3 NOT present\npositional3 NOT present\noption present with value: some\nAn option: some\nAn option: other\n" ++
    "positional present with value: value\nsubcmd NOT present\n";

const SCFOP =
    "flag present 1 times\noption NOT present\npositional NOT present\nflag2 NOT present\n" ++
    "option2 maybe present with value of: Nothing\npositional2 maybe present with value of: Nothing\n" ++
    "option3 NOT present\npositional3 NOT present\noption NOT present\npositional NOT present\n" ++
    "subcmd present\nflag present 1 times\nscoption present with value: some\nAn scoption: some\n" ++
    "scpositional present with value: value\n";

const SCF2OP =
    "flag present 2 times\noption NOT present\npositional NOT present\nflag2 NOT present\n" ++
    "option2 maybe present with value of: Nothing\npositional2 maybe present with value of: Nothing\n" ++
    "option3 NOT present\npositional3 NOT present\noption NOT present\npositional NOT present\n" ++
    "subcmd present\nflag present 2 times\nscoption present with value: some\nAn scoption: some\n" ++
    "scpositional present with value: value\n";

test "complex: top-level flag/option/positional matrix" {
    try check(&.{ "value", "-f", "-f", "-o", "some" }, F2OP); // flag_x2_opt
    try check(&.{ "value", "-ff", "-o", "some" }, F2OP); // short_flag_x2_comb_short_opt_pos
    try check(&.{ "value", "-f", "-o", "some" }, FOP); // short_flag_short_opt_pos
    try check(&.{ "value", "--flag", "--option", "some" }, FOP); // long_flag_long_opt_pos
    try check(&.{ "value", "--flag", "--option=some" }, FOP); // long_flag_long_opt_eq_pos
    try check(&.{ "value", "--option", "some", "--option", "other" }, O2P); // long_opt_x2_pos
    try check(&.{ "value", "--option=some", "--option=other" }, O2P); // long_opt_eq_x2_pos
    try check(&.{ "value", "-o", "some", "-o", "other" }, O2P); // short_opt_x2_pos
    try check(&.{ "value", "-o=some", "-o=other" }, O2P); // short_opt_eq_x2_pos
}

test "complex: subcommand + global flag (single)" {
    try check(&.{ "subcmd", "value", "--flag", "--option", "some" }, SCFOP);
    try check(&.{ "subcmd", "value", "--flag", "-o", "some" }, SCFOP);
    try check(&.{ "subcmd", "value", "--flag", "--option=some" }, SCFOP);
    try check(&.{ "subcmd", "value", "-f", "--option", "some" }, SCFOP);
    try check(&.{ "subcmd", "value", "-f", "-o", "some" }, SCFOP);
    try check(&.{ "subcmd", "value", "-f", "-o=some" }, SCFOP);
    try check(&.{ "subcmd", "value", "-f", "--option=some" }, SCFOP);
}

test "complex: subcommand + global flag (x2)" {
    try check(&.{ "subcmd", "value", "-ff", "--option", "some" }, SCF2OP);
    try check(&.{ "subcmd", "value", "-ff", "-o", "some" }, SCF2OP);
    try check(&.{ "subcmd", "value", "-ff", "--option=some" }, SCF2OP);
    try check(&.{ "subcmd", "value", "-ff", "-o=some" }, SCF2OP);
    try check(&.{ "subcmd", "value", "--flag", "--flag", "--option", "some" }, SCF2OP);
    try check(&.{ "subcmd", "value", "--flag", "--flag", "-o", "some" }, SCF2OP);
    try check(&.{ "subcmd", "value", "--flag", "--flag", "-o=some" }, SCF2OP);
    try check(&.{ "subcmd", "value", "--flag", "--flag", "--option=some" }, SCF2OP);
    try check(&.{ "subcmd", "value", "-f", "-f", "--option", "some" }, SCF2OP);
    try check(&.{ "subcmd", "value", "-f", "-f", "-o", "some" }, SCF2OP);
    try check(&.{ "subcmd", "value", "-f", "-f", "-o=some" }, SCF2OP);
    try check(&.{ "subcmd", "value", "-f", "-f", "--option=some" }, SCF2OP);
}

test "create_app / add_multiple_arg build and parse empty" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c1 = clap.Command.init(a, "test").version("1.0").author("kevin").about("does awesome things");
    try testing.expect(clap.getMatches(a, &c1, &.{}) == .matches);
    var c2 = clap.Command.init(a, "test")
        .arg(clap.Arg.new("test").short('s'))
        .arg(clap.Arg.new("test2").short('l'));
    try testing.expect(clap.getMatches(a, &c2, &.{}) == .matches);
}
