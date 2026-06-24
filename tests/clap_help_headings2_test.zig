//! Ported from clap's tests/builder/help.rs — custom help headings with mixed
//! argument types, multiple/overridden headings, and a positional-only heading.
//! https://github.com/clap-rs/clap/blob/master/tests/builder/help.rs

const std = @import("std");
const clap = @import("clap");

const testing = std.testing;
const Arg = clap.Arg;
const Command = clap.Command;

fn helpText(a: std.mem.Allocator, cmd: *Command) []const u8 {
    cmd.buildTree();
    return clap.renderError(a, clap.getMatches(a, cmd, &.{"--help"}).err);
}

test "mixed_argument_types" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog").about("mixed arguments").nextHelpHeading("Mixed")
        .arg(Arg.new("both").short('b').long("both").action(.set_true).help("Both long and short"))
        .arg(Arg.new("long").long("long").action(.set_true).help("Long only"))
        .arg(Arg.new("POSITIONAL").required(true).help("Positional"));
    try testing.expectEqualStrings(
        "mixed arguments\n\n" ++
            "Usage: myprog [OPTIONS] <POSITIONAL>\n\n" ++
            "Options:\n" ++
            "  -h, --help  Print help\n\n" ++
            "Mixed:\n" ++
            "  -b, --both    Both long and short\n" ++
            "      --long    Long only\n" ++
            "  <POSITIONAL>  Positional\n",
        helpText(a, &cmd),
    );
}

test "mixed_argument_types_no_short" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "myprog").about("mixed arguments").nextHelpHeading("Mixed")
        .arg(Arg.new("long").long("long").action(.set_true).help("Long only"))
        .arg(Arg.new("POSITIONAL").required(true).help("Positional"));
    try testing.expectEqualStrings(
        "mixed arguments\n\n" ++
            "Usage: myprog [OPTIONS] <POSITIONAL>\n\n" ++
            "Options:\n" ++
            "  -h, --help  Print help\n\n" ++
            "Mixed:\n" ++
            "      --long    Long only\n" ++
            "  <POSITIONAL>  Positional\n",
        helpText(a, &cmd),
    );
}

test "only_custom_heading_pos_no_args" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").version("1.4").disableVersionFlag(true).disableHelpFlag(true)
        .arg(Arg.new("help").long("help").action(.help).hide(true))
        .nextHelpHeading("NETWORKING")
        .arg(Arg.new("speed").help("How fast"));
    try testing.expectEqualStrings(
        "Usage: test [speed]\n\n" ++
            "NETWORKING:\n" ++
            "  [speed]  How fast\n",
        helpText(a, &cmd),
    );
}

test "multiple_custom_help_headers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var cmd = Command.init(a, "test").author("Will M.").about("does stuff").version("1.4")
        .arg(Arg.new("fake").short('f').long("fake").action(.set).required(true).valueNames(&.{ "some", "val" }).valueDelimiter(':').help("some help"))
        .nextHelpHeading("NETWORKING")
        .arg(Arg.new("no-proxy").short('n').long("no-proxy").action(.set_true).help("Do not use system proxy settings"))
        .nextHelpHeading("SPECIAL")
        .arg(Arg.new("birthday-song").short('b').long("birthday-song").action(.set).required(true).valueName("song").help("Change which song is played for birthdays").helpHeading("OVERRIDE SPECIAL"))
        .arg(Arg.new("style").long("style").action(.set).help("Choose musical style to play the song").helpHeading(null))
        .arg(Arg.new("birthday-song-volume").short('v').long("birthday-song-volume").action(.set).required(true).valueName("volume").help("Change the volume of the birthday song"))
        .nextHelpHeading(null)
        .arg(Arg.new("server-addr").short('a').long("server-addr").action(.set_true).help("Set server address").helpHeading("NETWORKING"))
        .arg(Arg.new("speed").long("speed").short('s').valueName("SPEED").valueParser(&.{ "fast", "slow" }).help("How fast?").action(.set));
    try testing.expectEqualStrings(
        "does stuff\n\n" ++
            "Usage: test [OPTIONS] --fake <some> <val> --birthday-song <song> --birthday-song-volume <volume>\n\n" ++
            "Options:\n" ++
            "  -f, --fake <some> <val>  some help\n" ++
            "      --style <style>      Choose musical style to play the song\n" ++
            "  -s, --speed <SPEED>      How fast? [possible values: fast, slow]\n" ++
            "  -h, --help               Print help\n" ++
            "  -V, --version            Print version\n\n" ++
            "NETWORKING:\n" ++
            "  -n, --no-proxy     Do not use system proxy settings\n" ++
            "  -a, --server-addr  Set server address\n\n" ++
            "OVERRIDE SPECIAL:\n" ++
            "  -b, --birthday-song <song>  Change which song is played for birthdays\n\n" ++
            "SPECIAL:\n" ++
            "  -v, --birthday-song-volume <volume>  Change the volume of the birthday song\n",
        helpText(a, &cmd),
    );
}
