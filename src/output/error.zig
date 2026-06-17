const std = @import("std");
const errors = @import("../error.zig");
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
            return help.render(allocator, e.cmd);
        },
        .display_version => {
            return std.fmt.allocPrint(allocator, "{s} {s}\n", .{
                e.cmd.name,
                e.cmd.version_str orelse "",
            }) catch @panic("clap: OOM rendering output");
        },
        else => {},
    }
    var b = Buf{ .allocator = allocator };
    b.add("error: ");
    appendMessage(&b, e);
    b.add("\n\n");
    b.add(usage.render(allocator, e.cmd));
    b.add("\n\nFor more information, try '--help'.\n");
    return b.items();
}

fn appendMessage(b: *Buf, e: errors.Error) void {
    const arg = e.arg orelse "";
    switch (e.kind) {
        .invalid_value => b.print("invalid value '{s}' for '{s}'", .{ e.value orelse "", arg }),
        .unknown_argument => b.print("unexpected argument '{s}' found", .{arg}),
        .no_equals => b.print("equal sign is needed when assigning values to '{s}'", .{arg}),
        .too_many_values => b.print("unexpected value '{s}' for '{s}'", .{ e.value orelse "", arg }),
        .argument_conflict => b.print("the argument '{s}' cannot be used with a subcommand", .{arg}),
        .invalid_subcommand => b.print("unrecognized subcommand '{s}'", .{arg}),
        .missing_required_argument => {
            b.add("the following required arguments were not provided:\n  ");
            b.add(arg);
        },
        .missing_subcommand => b.print("'{s}' requires a subcommand but one was not provided", .{e.cmd.displayName()}),
        .display_help, .display_help_on_missing_argument_or_subcommand, .display_version => unreachable,
    }
}
