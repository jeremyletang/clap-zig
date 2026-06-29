const std = @import("std");
const errors = @import("../error.zig");
const command = @import("../builder/command.zig");
const help = @import("help.zig");
const usage = @import("usage.zig");
const layout = @import("layout.zig");

const Buf = layout.Buf;

/// Render the text for an `Outcome.err`: help text for help/version requests,
/// otherwise a clap-style error block:
///
///     error: <message>
///
///     Usage: <usage>
///
///     For more information, try '--help'.
///
/// NOTE: the exact wording of error messages is not yet verified byte-for-byte
/// against clap (git.md exercises only the help-display paths); this will be
/// pinned down when clap's error.rs tests are ported.
pub fn render(allocator: std.mem.Allocator, e: errors.Error) []const u8 {
    switch (e.kind) {
        .display_help, .display_help_on_missing_argument_or_subcommand => {
            return help.render(allocator, e.cmd, e.help_long);
        },
        .display_version => {
            const ver = if (e.version_long)
                e.cmd.long_version_str orelse e.cmd.version_str
            else
                e.cmd.version_str orelse e.cmd.long_version_str;
            return std.fmt.allocPrint(allocator, "{s} {s}\n", .{
                e.cmd.name,
                ver orelse "",
            }) catch @panic("clap: OOM rendering output");
        },
        else => {},
    }
    var b = Buf{ .allocator = allocator };
    b.role(.err, "error:");
    b.addByte(' ');
    appendMessage(&b, e);
    b.addByte('\n');
    appendSuggestions(&b, e);
    if (usesUsage(e.kind)) {
        b.addByte('\n');
        b.add(usage.errorUsage(allocator, e.cmd, e.used_ids orelse &.{}));
        b.addByte('\n');
    }
    if (helpHint(allocator, e.cmd)) |h| {
        b.print("\nFor more information, try '{s}'.\n", .{h});
    } else {
        b.addByte('\n');
    }
    return b.items();
}

/// The token clap suggests for more help (clap's try-help logic): the auto or
/// user-defined help flag (prefer `--long`, else `-short`), else the `help`
/// subcommand, else nothing.
fn helpHint(allocator: std.mem.Allocator, cmd: *const command.Command) ?[]const u8 {
    if (!cmd.is_multicall and !cmd.disable_help_flag) return "--help";
    for (cmd.arg_list.items) |*a| {
        switch (a.action_val) {
            .help, .help_short, .help_long => {
                if (a.long_name) |l| return std.fmt.allocPrint(allocator, "--{s}", .{l}) catch @panic("clap: OOM");
                if (a.short_char) |c| return std.fmt.allocPrint(allocator, "-{c}", .{c}) catch @panic("clap: OOM");
            },
            else => {},
        }
    }
    if (cmd.hasSubcommands() and !cmd.disable_help_subcommand) return "help";
    return null;
}

/// Whether this error kind prints a `Usage:` block (clap omits it for invalid_value).
fn usesUsage(kind: errors.ErrorKind) bool {
    return kind != .invalid_value;
}

/// Rust-`{:?}`-style quoting for a possible value (clap's `Escape`): wrap in
/// double quotes (escaping `"`/`\`) when empty or containing whitespace.
fn escapeValue(allocator: std.mem.Allocator, v: []const u8) []const u8 {
    var needs = v.len == 0;
    for (v) |c| {
        if (std.ascii.isWhitespace(c)) needs = true;
    }
    if (!needs) return v;
    var b = Buf{ .allocator = allocator };
    b.addByte('"');
    for (v) |c| {
        if (c == '"' or c == '\\') b.addByte('\\');
        b.addByte(c);
    }
    b.addByte('"');
    return b.items();
}

/// The "tip:" line for a "did you mean" suggestion (clap's `did_you_mean`).
fn appendSuggestions(b: *Buf, e: errors.Error) void {
    const sugg = e.suggestions orelse return;
    if (sugg.len == 0) return;
    const ctx = switch (e.kind) {
        .invalid_subcommand => "subcommand",
        .invalid_value => "value",
        else => "argument",
    };
    b.add("\n  ");
    b.role(.valid, "tip:");
    if (sugg.len == 1) {
        b.print(" a similar {s} exists: ", .{ctx});
    } else {
        b.print(" some similar {s}s exist: ", .{ctx});
    }
    for (sugg, 0..) |s, i| {
        if (i != 0) b.add(", ");
        b.addByte('\'');
        b.role(.valid, s);
        b.addByte('\'');
    }
    b.addByte('\n');
}

fn appendMessage(b: *Buf, e: errors.Error) void {
    const arg = e.arg orelse "";
    switch (e.kind) {
        .wrong_number_of_values => b.print("{d} values required for '{s}' but {d} {s} provided", .{
            e.n_expected, arg, e.n_provided, if (e.n_provided == 1) "was" else "were",
        }),
        .too_few_values => b.print("{d} values required by '{s}'; only {d} were provided", .{
            e.n_expected, arg, e.n_provided,
        }),
        .invalid_value => {
            if (e.value_required) {
                b.print("a value is required for '{s}' but none was supplied", .{arg});
                return;
            }
            b.print("invalid value '{s}' for '{s}'", .{ e.value orelse "", arg });
            if (e.reason) |r| b.print(": {s}", .{r});
            if (e.possible_values) |pv| {
                b.add("\n  [possible values: ");
                for (pv, 0..) |v, i| {
                    if (i != 0) b.add(", ");
                    b.role(.valid, escapeValue(b.allocator, v));
                }
                b.add("]");
            }
        },
        .unknown_argument => b.print("unexpected argument '{s}' found", .{arg}),
        .no_equals => b.print("equal sign is needed when assigning values to '{s}'", .{arg}),
        .too_many_values => b.print("unexpected value '{s}' for '{s}' found; no more were expected", .{ e.value orelse "", arg }),
        .argument_conflict => {
            if (e.multiple_use) {
                b.print("the argument '{s}' cannot be used multiple times", .{arg});
            } else if (e.conflicts) |others| {
                if (others.len == 1) {
                    b.print("the argument '{s}' cannot be used with '{s}'", .{ arg, others[0] });
                } else {
                    b.print("the argument '{s}' cannot be used with:", .{arg});
                    for (others) |o| b.print("\n  {s}", .{o});
                }
            } else {
                b.print("the argument '{s}' cannot be used with a subcommand", .{arg});
            }
        },
        .invalid_subcommand => b.print("unrecognized subcommand '{s}'", .{arg}),
        .missing_required_argument => {
            b.add("the following required arguments were not provided:\n  ");
            b.add(arg);
        },
        .missing_subcommand => {
            b.print("'{s}' requires a subcommand but one was not provided", .{e.cmd.displayName()});
            b.add("\n  [subcommands: ");
            var first = true;
            for (e.cmd.subcommands.items) |*sc| {
                if (sc.is_hidden) continue;
                if (!first) b.add(", ");
                b.add(sc.name);
                first = false;
            }
            if (!e.cmd.disable_help_subcommand) {
                if (!first) b.add(", ");
                b.add("help");
            }
            b.add("]");
        },
        .display_help, .display_help_on_missing_argument_or_subcommand, .display_version => unreachable,
    }
}
