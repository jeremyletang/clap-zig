//! Port of clap's shared `complex_app()` fixture + `check_complex_output()`:
//! https://github.com/clap-rs/clap/blob/master/tests/builder/utils.rs
//! https://github.com/clap-rs/clap/blob/master/tests/builder/tests.rs

const std = @import("std");
const clap = @import("clap");

const Command = clap.Command;
const Arg = clap.Arg;
const range = clap.ValueRange;

const FULL_TEMPLATE =
    "{before-help}{name} {version}\n" ++
    "{author-with-newline}{about-with-newline}\n" ++
    "{usage-heading} {usage}\n" ++
    "\n" ++
    "{all-args}{after-help}";

pub fn complexApp(a: std.mem.Allocator) Command {
    return Command.init(a, "clap-test")
        .version("v1.4.8")
        .about("tests clap library")
        .author("Kevin K. <kbknapp@gmail.com>")
        .helpTemplate(FULL_TEMPLATE)
        .arg(Arg.fromUsage("-o --option <opt>", "tests options").required(false).numArgs(range.atLeast(1)).action(.append))
        .arg(Arg.fromUsage("[positional]", "tests positionals"))
        .arg(Arg.fromUsage("-f --flag", "tests flags").action(.count).global(true))
        .arg(Arg.fromUsage("flag2: -F", "tests flags with exclusions").conflictsWith("flag").requires("long-option-2").action(.set_true))
        .arg(Arg.fromUsage("--long-option-2 <option2>", "tests long options with exclusions").conflictsWith("option").requires("positional2"))
        .arg(Arg.fromUsage("[positional2]", "tests positionals with exclusions"))
        .arg(Arg.fromUsage("-O --option3 <option3>", "specific vals").valueParser(&.{ "fast", "slow" }))
        .arg(Arg.fromUsage("[positional3]...", "tests specific values").valueParser(&.{ "vi", "emacs" }))
        .arg(Arg.fromUsage("--multvals <val>", "Tests multiple values, not mult occs").valueNames(&.{ "one", "two" }))
        .arg(Arg.fromUsage("--multvalsmo <val>...", "Tests multiple values, and mult occs").valueNames(&.{ "one", "two" }))
        .arg(Arg.fromUsage("--minvals2 <minvals>", "Tests 2 min vals").numArgs(range.atLeast(2)))
        .arg(Arg.fromUsage("--maxvals3 <maxvals>", "Tests 3 max vals").numArgs(range.between(1, 3)))
        .arg(Arg.fromUsage("--optvaleq <optval>", "Tests optional value, require = sign").numArgs(range.between(0, 1)).requireEquals(true))
        .arg(Arg.fromUsage("--optvalnoeq <optval>", "Tests optional value").numArgs(range.between(0, 1)))
        .subcommand(Command.init(a, "subcmd")
            .about("tests subcommands")
            .version("0.1")
            .author("Kevin K. <kbknapp@gmail.com>")
            .helpTemplate(FULL_TEMPLATE)
            .arg(Arg.fromUsage("-o --option <scoption>", "tests options").numArgs(range.atLeast(1)))
            .arg(Arg.fromUsage("-s --subcmdarg <subcmdarg>", "tests other args"))
            .arg(Arg.fromUsage("[scpositional]", "tests positionals")));
}

const Buf = struct {
    a: std.mem.Allocator,
    list: std.ArrayListUnmanaged(u8) = .empty,
    fn line(b: *Buf, comptime fmt: []const u8, args: anytype) void {
        const s = std.fmt.allocPrint(b.a, fmt ++ "\n", args) catch @panic("OOM");
        b.list.appendSlice(b.a, s) catch @panic("OOM");
    }
};

/// Replica of clap's check_complex_output: render a fixed report of what parsed.
pub fn checkComplex(a: std.mem.Allocator, m: *const clap.ArgMatches) []const u8 {
    var b = Buf{ .a = a };
    reportCommon(&b, m, "option", "positional");
    if (m.subcommand()) |s| {
        if (std.mem.eql(u8, s.name, "subcmd")) {
            b.line("subcmd present", .{});
            reportSub(&b, s.matches);
            return b.list.items;
        }
    }
    b.line("subcmd NOT present", .{});
    return b.list.items;
}

fn reportCommon(b: *Buf, m: *const clap.ArgMatches, opt: []const u8, pos: []const u8) void {
    // flag
    const fc = m.getCount("flag");
    if (fc == 0) b.line("flag NOT present", .{}) else b.line("flag present {d} times", .{fc});
    reportOptPos(b, m, opt, pos, "option", "positional");
    // flag2 block
    if (m.getFlag("flag2")) {
        b.line("flag2 present", .{});
        b.line("option2 present with value of: {s}", .{m.getOne([]const u8, "long-option-2").?});
        b.line("positional2 present with value of: {s}", .{m.getOne([]const u8, "positional2").?});
    } else {
        b.line("flag2 NOT present", .{});
        b.line("option2 maybe present with value of: {s}", .{m.getOne([]const u8, "long-option-2") orelse "Nothing"});
        b.line("positional2 maybe present with value of: {s}", .{m.getOne([]const u8, "positional2") orelse "Nothing"});
    }
    // option3
    const o3 = m.getOne([]const u8, "option3") orelse "";
    if (std.mem.eql(u8, o3, "fast")) b.line("option3 present quickly", .{}) else if (std.mem.eql(u8, o3, "slow")) b.line("option3 present slowly", .{}) else b.line("option3 NOT present", .{});
    // positional3
    const p3 = m.getOne([]const u8, "positional3") orelse "";
    if (std.mem.eql(u8, p3, "vi")) b.line("positional3 present in vi mode", .{}) else if (std.mem.eql(u8, p3, "emacs")) b.line("positional3 present in emacs mode", .{}) else b.line("positional3 NOT present", .{});
    // option + positional again
    reportOptPos(b, m, opt, pos, "option", "positional");
}

fn reportOptPos(b: *Buf, m: *const clap.ArgMatches, opt: []const u8, pos: []const u8, opt_label: []const u8, pos_label: []const u8) void {
    _ = opt_label;
    _ = pos_label;
    if (m.contains(opt)) {
        if (m.getOne([]const u8, opt)) |v| b.line("option present with value: {s}", .{v});
        if (m.getMany([]const u8, opt)) |ov| for (ov) |o| b.line("An option: {s}", .{o});
    } else {
        b.line("option NOT present", .{});
    }
    if (m.getOne([]const u8, pos)) |p| b.line("positional present with value: {s}", .{p}) else b.line("positional NOT present", .{});
}

fn reportSub(b: *Buf, m: *const clap.ArgMatches) void {
    const fc = m.getCount("flag");
    if (fc == 0) b.line("flag NOT present", .{}) else b.line("flag present {d} times", .{fc});
    if (m.contains("option")) {
        if (m.getOne([]const u8, "option")) |v| b.line("scoption present with value: {s}", .{v});
        if (m.getMany([]const u8, "option")) |ov| for (ov) |o| b.line("An scoption: {s}", .{o});
    } else {
        b.line("scoption NOT present", .{});
    }
    if (m.getOne([]const u8, "scpositional")) |p| b.line("scpositional present with value: {s}", .{p});
}
