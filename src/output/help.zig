const std = @import("std");
const command = @import("../builder/command.zig");
const arg = @import("../builder/arg.zig");
const layout = @import("layout.zig");
const usage = @import("usage.zig");

const Command = command.Command;
const Arg = arg.Arg;
const Buf = layout.Buf;
const Entry = layout.Entry;

const help_about = "Print this message or the help of the given subcommand(s)";
const help_flag_help = "Print help";

/// Render a command's long help (`--help` / `help <cmd>`), byte-compatible with
/// clap. Port of https://github.com/clap-rs/clap/blob/master/clap_builder/src/output/help_template.rs
pub fn render(allocator: std.mem.Allocator, cmd: *const Command) []const u8 {
    var b = Buf{ .allocator = allocator };
    if (cmd.flatten_help and cmd.hasSubcommands()) {
        renderFlattened(&b, cmd);
        return b.items();
    }
    if (cmd.about_text) |t| {
        b.add(t);
        b.add("\n\n");
    }
    b.add(usage.render(allocator, cmd));
    b.addByte('\n');
    if (hasListedSubcommands(cmd)) writeCommands(&b, cmd);
    if (hasPositionals(cmd)) writeArguments(&b, cmd);
    writeOptions(&b, cmd);
    return b.items();
}

// ----- flatten_help (clap's `flatten`) -----

fn renderFlattened(b: *Buf, cmd: *const Command) void {
    if (cmd.about_text) |t| {
        b.add(t);
        b.add("\n\n");
    }
    b.add("Usage: ");
    usage.appendBody(b, cmd, false);
    b.addByte('\n');
    for (cmd.subcommands.items) |*sc| usageLine(b, sc);
    const help_sub = makeHelpSubcommand(b.allocator, cmd);
    if (!cmd.disable_help_subcommand) usageLine(b, &help_sub);

    if (hasPositionals(cmd)) writeArguments(b, cmd);
    writeOptions(b, cmd);

    for (cmd.subcommands.items) |*sc| flattenedBlock(b, sc);
    if (!cmd.disable_help_subcommand) flattenedBlock(b, &help_sub);
}

fn usageLine(b: *Buf, cmd: *const Command) void {
    b.spaces(7); // align under "Usage: "
    usage.appendBody(b, cmd, true);
    b.addByte('\n');
}

/// One subcommand's flattened block under flatten_help: a `bin:` header, the
/// subcommand's about (if any), then its options and positionals in a single
/// unheaded table.
fn flattenedBlock(b: *Buf, cmd: *const Command) void {
    b.addByte('\n');
    b.add(cmd.displayName());
    b.add(":\n");
    if (cmd.about_text) |t| {
        b.add(t);
        b.addByte('\n');
    }
    var entries: std.ArrayListUnmanaged(Entry) = .empty;
    collectOptions(b.allocator, cmd, &entries);
    collectPositionals(b.allocator, cmd, &entries);
    layout.table(b, 2, entries.items);
}

fn makeHelpSubcommand(allocator: std.mem.Allocator, parent: *const Command) Command {
    var c = Command.init(allocator, "help")
        .about(help_about)
        .arg(Arg.fromUsage("[COMMAND]...", "Print help for the subcommand(s)"));
    c.bin_name = std.fmt.allocPrint(allocator, "{s} help", .{parent.displayName()}) catch
        @panic("clap: OOM rendering output");
    c.disable_help_flag = true;
    c.disable_help_subcommand = true;
    return c;
}

// ----- Commands -----

fn writeCommands(b: *Buf, cmd: *const Command) void {
    var entries: std.ArrayListUnmanaged(Entry) = .empty;
    for (cmd.subcommands.items) |*sc| {
        entries.append(b.allocator, .{ .term = sc.name, .help = sc.about_text orelse "" }) catch oom();
    }
    if (!cmd.disable_help_subcommand) {
        entries.append(b.allocator, .{ .term = "help", .help = help_about }) catch oom();
    }
    b.addByte('\n');
    b.add("Commands:\n");
    layout.table(b, 2, entries.items);
}

// ----- Arguments (positionals) -----

fn writeArguments(b: *Buf, cmd: *const Command) void {
    var entries: std.ArrayListUnmanaged(Entry) = .empty;
    collectPositionals(b.allocator, cmd, &entries);
    b.addByte('\n');
    b.add("Arguments:\n");
    layout.table(b, 2, entries.items);
}

fn collectPositionals(allocator: std.mem.Allocator, cmd: *const Command, entries: *std.ArrayListUnmanaged(Entry)) void {
    var i: usize = 1;
    while (cmd.getPositional(i)) |a| : (i += 1) {
        entries.append(allocator, .{
            .term = layout.positionalNotationStr(allocator, a),
            .help = argHelp(allocator, a),
        }) catch oom();
    }
}

// ----- Options -----

fn writeOptions(b: *Buf, cmd: *const Command) void {
    var entries: std.ArrayListUnmanaged(Entry) = .empty;
    collectOptions(b.allocator, cmd, &entries);
    b.addByte('\n');
    b.add("Options:\n");
    layout.table(b, 2, entries.items);
}

fn collectOptions(allocator: std.mem.Allocator, cmd: *const Command, entries: *std.ArrayListUnmanaged(Entry)) void {
    for (cmd.arg_list.items) |*a| {
        if (a.isPositional()) continue;
        entries.append(allocator, .{
            .term = optionTerm(allocator, a),
            .help = argHelp(allocator, a),
        }) catch oom();
    }
    if (!cmd.disable_help_flag) {
        entries.append(allocator, .{ .term = "-h, --help", .help = help_flag_help }) catch oom();
    }
    if (cmd.hasVersionFlag()) {
        entries.append(allocator, .{ .term = "-V, --version", .help = "Print version" }) catch oom();
    }
}

fn oom() noreturn {
    @panic("clap: OOM rendering output");
}

fn optionTerm(allocator: std.mem.Allocator, a: *const Arg) []const u8 {
    var b = Buf{ .allocator = allocator };
    if (a.short_char) |c| {
        if (a.long_name != null) b.print("-{c}, ", .{c}) else b.print("-{c}", .{c});
    } else {
        b.spaces(4);
    }
    if (a.long_name) |l| {
        b.add("--");
        b.add(l);
    }
    appendValueNotation(&b, a);
    if (a.action_val == .count) b.add("...");
    return b.items();
}

fn appendValueNotation(b: *Buf, a: *const Arg) void {
    if (!a.takesValue()) return;
    const name = a.value_name orelse a.id;
    if (a.require_equals and a.effectiveNumArgs().min == 0) {
        b.add("[=<");
        b.add(name);
        b.add(">]");
    } else {
        b.add(" <");
        b.add(name);
        b.add(">");
    }
}

fn argHelp(allocator: std.mem.Allocator, a: *const Arg) []const u8 {
    var b = Buf{ .allocator = allocator };
    if (a.help_str) |h| b.add(h);
    if (a.default_value) |d| {
        sep(&b);
        b.add("[default: ");
        b.add(d);
        b.add("]");
    }
    if (a.possible_values) |pv| {
        sep(&b);
        b.add("[possible values: ");
        for (pv, 0..) |v, idx| {
            if (idx != 0) b.add(", ");
            b.add(v);
        }
        b.add("]");
    }
    return b.items();
}

fn sep(b: *Buf) void {
    if (b.items().len != 0) b.addByte(' ');
}

// ----- queries -----

fn hasListedSubcommands(cmd: *const Command) bool {
    // the synthetic `help` subcommand is only listed when there are real ones
    return cmd.hasSubcommands();
}

fn hasPositionals(cmd: *const Command) bool {
    return cmd.countPositionals() > 0;
}
