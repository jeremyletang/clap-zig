const std = @import("std");
const command = @import("../builder/command.zig");
const arg = @import("../builder/arg.zig");
const layout = @import("layout.zig");

const Command = command.Command;
const Arg = arg.Arg;
const Buf = layout.Buf;

/// The single-line usage string, e.g. "git diff [OPTIONS] [COMMIT] [COMMIT] [-- <PATH>]".
/// Port of https://github.com/clap-rs/clap/blob/master/clap_builder/src/output/usage.rs
pub fn render(allocator: std.mem.Allocator, cmd: *const Command) []const u8 {
    var b = Buf{ .allocator = allocator };
    b.add("Usage: ");
    appendBody(&b, cmd, true);
    return b.items();
}

/// Usage without the "Usage: " prefix — the part after the binary name shape,
/// reused for the multi-line flattened form. `include_subcommand` is false for
/// the top line of a flattened usage, where subcommands are listed separately.
pub fn appendBody(b: *Buf, cmd: *const Command, include_subcommand: bool) void {
    b.add(cmd.displayName());
    if (hasOptions(cmd)) b.add(" [OPTIONS]");
    appendPositionals(b, cmd);
    if (include_subcommand) appendSubcommandToken(b, cmd);
}

fn appendPositionals(b: *Buf, cmd: *const Command) void {
    var i: usize = 1;
    while (cmd.getPositional(i)) |a| : (i += 1) {
        if (a.last_flag) continue;
        b.addByte(' ');
        layout.positionalNotation(b, a);
    }
    if (lastPositional(cmd)) |a| {
        b.add(" [-- <");
        b.add(a.value_name orelse a.id);
        b.add(">");
        if (a.isMultiple()) b.add("...");
        b.add("]");
    }
}

fn appendSubcommandToken(b: *Buf, cmd: *const Command) void {
    if (!cmd.hasSubcommands()) return;
    b.add(if (cmd.subcommand_required) " <COMMAND>" else " [COMMAND]");
}

pub fn hasOptions(cmd: *const Command) bool {
    for (cmd.arg_list.items) |*a| {
        if (!a.isPositional()) return true;
    }
    return false;
}

pub fn lastPositional(cmd: *const Command) ?*const Arg {
    for (cmd.arg_list.items) |*a| {
        if (a.last_flag) return a;
    }
    return null;
}
