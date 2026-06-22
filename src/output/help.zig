const std = @import("std");
const command = @import("../builder/command.zig");
const arg = @import("../builder/arg.zig");
const possible_value = @import("../builder/possible_value.zig");
const layout = @import("layout.zig");
const usage = @import("usage.zig");

const Command = command.Command;
const Arg = arg.Arg;
const PossibleValue = possible_value.PossibleValue;
const Buf = layout.Buf;
const Entry = layout.Entry;

const help_about = "Print this message or the help of the given subcommand(s)";
const help_flag_help = "Print help";

/// Render a command's help. `long` selects the expanded `--help` layout (used
/// only when the command actually has long-only content); otherwise the compact
/// `-h` layout. Port of https://github.com/clap-rs/clap/blob/master/clap_builder/src/output/help_template.rs
pub fn render(allocator: std.mem.Allocator, cmd: *const Command, long: bool) []const u8 {
    if (cmd.flatten_help and cmd.hasSubcommands()) {
        var fb = Buf{ .allocator = allocator };
        renderFlattened(&fb, cmd);
        return fb.items();
    }
    if (cmd.help_template_text) |t| return trimTrailing(allocator, renderTemplate(allocator, cmd, t, long));
    const out = if (long and hasLongHelp(cmd)) renderLong(allocator, cmd) else renderShort(allocator, cmd);
    return trimTrailing(allocator, out);
}

/// Expand a `help_template`: literal text with `{tag}` placeholders. Unknown
/// tags are emitted verbatim (`{tag}`). Port of clap's `write_templated_help`.
fn renderTemplate(allocator: std.mem.Allocator, cmd: *const Command, template: []const u8, long: bool) []const u8 {
    var b = Buf{ .allocator = allocator };
    var parts = std.mem.splitScalar(u8, template, '{');
    if (parts.next()) |first| b.add(first);
    while (parts.next()) |part| {
        const close = std.mem.indexOfScalar(u8, part, '}') orelse {
            b.addByte('{');
            b.add(part);
            continue;
        };
        emitTag(&b, cmd, part[0..close], long);
        b.add(part[close + 1 ..]);
    }
    return b.items();
}

fn emitTag(b: *Buf, cmd: *const Command, tag: []const u8, long: bool) void {
    const eq = std.mem.eql;
    if (eq(u8, tag, "name") or eq(u8, tag, "bin")) {
        b.add(cmd.displayName());
    } else if (eq(u8, tag, "version")) {
        if (cmd.version_str) |v| b.add(v);
    } else if (eq(u8, tag, "author")) {
        if (cmd.author_text) |a| b.add(a);
    } else if (eq(u8, tag, "author-with-newline")) {
        if (cmd.author_text) |a| {
            b.add(a);
            b.addByte('\n');
        }
    } else if (eq(u8, tag, "author-section")) {
        if (cmd.author_text) |a| {
            b.add(a);
            b.add("\n\n");
        }
    } else if (eq(u8, tag, "about")) {
        if (cmd.aboutText(long)) |a| b.add(a);
    } else if (eq(u8, tag, "about-with-newline")) {
        if (cmd.aboutText(long)) |a| {
            b.add(a);
            b.addByte('\n');
        }
    } else if (eq(u8, tag, "about-section")) {
        if (cmd.aboutText(long)) |a| {
            b.add(a);
            b.add("\n\n");
        }
    } else if (eq(u8, tag, "usage-heading")) {
        b.add("Usage:");
    } else if (eq(u8, tag, "usage")) {
        b.add(cmd.usage_override orelse usage.appendBody(b.allocator, cmd, true));
    } else if (eq(u8, tag, "all-args")) {
        writeAllArgs(b, cmd, long);
    } else if (eq(u8, tag, "options")) {
        b.add(optionRows(b.allocator, cmd, long));
    } else if (eq(u8, tag, "positionals")) {
        b.add(positionalRows(b.allocator, cmd, long));
    } else if (eq(u8, tag, "subcommands")) {
        b.add(subcommandRows(b.allocator, cmd));
    } else if (eq(u8, tag, "tab")) {
        b.add("  ");
    } else if (eq(u8, tag, "before-help")) {
        if (cmd.before_help_text) |t| b.add(t);
    } else if (eq(u8, tag, "after-help")) {
        if (cmd.after_help_text) |t| b.add(t);
    } else {
        b.addByte('{');
        b.add(tag);
        b.addByte('}');
    }
}

/// clap trims trailing whitespace from the end of the help and terminates with a
/// single newline (so the last line of a section never keeps padding spaces).
fn trimTrailing(allocator: std.mem.Allocator, s: []const u8) []const u8 {
    const trimmed = std.mem.trimEnd(u8, s, " \n");
    return std.fmt.allocPrint(allocator, "{s}\n", .{trimmed}) catch oom();
}

fn renderShort(allocator: std.mem.Allocator, cmd: *const Command) []const u8 {
    var b = Buf{ .allocator = allocator };
    if (cmd.before_help_text) |t| {
        b.add(t);
        b.add("\n\n");
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
    appendAfterHelp(&b, cmd.after_help_text);
    return b.items();
}

/// Append free text after the help body, separated by a blank line (clap's
/// `{after-help}`).
fn appendAfterHelp(b: *Buf, text: ?[]const u8) void {
    if (text) |t| {
        b.addByte('\n');
        b.add(t);
        b.addByte('\n');
    }
}

/// Whether `--help` should use the expanded next-line layout, i.e. there is
/// content that only appears in long help: per-value help, a long about, or
/// long before/after text.
fn hasLongHelp(cmd: *const Command) bool {
    if (cmd.long_about_text != null) return true;
    if (cmd.before_long_help_text != null or cmd.after_long_help_text != null) return true;
    for (cmd.arg_list.items) |*a| {
        if (a.is_hidden) continue;
        // anything that differs between -h and --help forces the long layout
        if (a.value_help != null or a.hide_short_help or a.hide_long_help) return true;
    }
    return false;
}

// ----- long help (`--help`): next-line layout with expanded possible values -----

const LongEntry = struct { term: []const u8, help: []const u8, pvs: ?[]const PossibleValue = null };

fn renderLong(allocator: std.mem.Allocator, cmd: *const Command) []const u8 {
    var b = Buf{ .allocator = allocator };
    if (cmd.before_long_help_text orelse cmd.before_help_text) |t| {
        b.add(t);
        b.add("\n\n");
    }
    if (cmd.long_about_text orelse cmd.about_text) |t| {
        b.add(t);
        b.add("\n\n");
    }
    b.add(usage.render(allocator, cmd));
    b.addByte('\n');
    if (hasListedSubcommands(cmd)) {
        b.add("\nCommands:\n");
        longSection(&b, longCommands(allocator, cmd));
    }
    if (hasPositionals(cmd)) {
        b.add("\nArguments:\n");
        longSection(&b, longArguments(allocator, cmd));
    }
    b.add("\nOptions:\n");
    longSection(&b, longOptions(allocator, cmd));
    appendAfterHelp(&b, cmd.after_long_help_text orelse cmd.after_help_text);
    return b.items();
}

fn longSection(b: *Buf, entries: []const LongEntry) void {
    for (entries, 0..) |e, i| {
        if (i != 0) b.addByte('\n'); // blank line between entries
        b.add("  ");
        b.add(e.term);
        b.addByte('\n');
        if (e.help.len != 0) {
            b.add("          ");
            b.add(e.help);
            b.addByte('\n');
        }
        if (e.pvs) |pvs| {
            b.add("\n          Possible values:\n");
            for (pvs) |v| {
                b.add("          - ");
                b.add(v.name);
                if (v.help) |h| {
                    b.add(": ");
                    b.add(h);
                }
                b.addByte('\n');
            }
        }
    }
}

fn longCommands(allocator: std.mem.Allocator, cmd: *const Command) []const LongEntry {
    var entries: std.ArrayListUnmanaged(LongEntry) = .empty;
    for (cmd.subcommands.items) |*sc| {
        if (sc.is_hidden) continue;
        entries.append(allocator, .{ .term = sc.name, .help = sc.about_text orelse "" }) catch oom();
    }
    if (!cmd.disable_help_subcommand) {
        entries.append(allocator, .{ .term = "help", .help = help_about }) catch oom();
    }
    return entries.items;
}

fn longArguments(allocator: std.mem.Allocator, cmd: *const Command) []const LongEntry {
    var entries: std.ArrayListUnmanaged(LongEntry) = .empty;
    var i: usize = 1;
    while (cmd.getPositional(i)) |a| : (i += 1) {
        if (!a.shownIn(true)) continue;
        entries.append(allocator, .{
            .term = layout.positionalNotationStr(allocator, a),
            .help = a.help_str orelse "",
            .pvs = a.value_help,
        }) catch oom();
    }
    return entries.items;
}

fn longOptions(allocator: std.mem.Allocator, cmd: *const Command) []const LongEntry {
    var entries: std.ArrayListUnmanaged(LongEntry) = .empty;
    for (cmd.arg_list.items) |*a| {
        if (a.isPositional() or !a.shownIn(true)) continue;
        entries.append(allocator, .{
            .term = optionTerm(allocator, a),
            .help = a.help_str orelse "",
            .pvs = a.value_help,
        }) catch oom();
    }
    if (!cmd.disable_help_flag) {
        entries.append(allocator, .{ .term = "-h, --help", .help = "Print help (see a summary with '-h')" }) catch oom();
    }
    if (cmd.hasVersionFlag()) {
        entries.append(allocator, .{ .term = "-V, --version", .help = "Print version" }) catch oom();
    }
    return entries.items;
}

// ----- flatten_help (clap's `flatten`) -----

fn renderFlattened(b: *Buf, cmd: *const Command) void {
    if (cmd.about_text) |t| {
        b.add(t);
        b.add("\n\n");
    }
    b.add("Usage: ");
    b.add(usage.appendBody(b.allocator, cmd, false));
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
    b.add(usage.appendBody(b.allocator, cmd, true));
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
    layout.table(b, 2, entries.items, cmd.term_width);
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

/// A subcommand's Commands-list help: its about plus `[aliases: a, b]` for any
/// visible aliases (subcommand aliases are bare names, no dashes).
fn subcommandHelp(allocator: std.mem.Allocator, sc: *const Command) []const u8 {
    const vis = sc.visible_aliases_list orelse return sc.about_text orelse "";
    if (vis.len == 0) return sc.about_text orelse "";
    var b = Buf{ .allocator = allocator };
    if (sc.about_text) |t| {
        b.add(t);
        b.addByte(' ');
    }
    b.add("[aliases: ");
    for (vis, 0..) |x, i| {
        if (i != 0) b.add(", ");
        b.add(x);
    }
    b.add("]");
    return b.items();
}

// ----- display-order sorting -----

/// A table row tagged with its sort position: `(display_order, secondary key)`
/// per clap's `option_sort_key`. Equal orders fall back to the key.
const SortRow = struct { ord: usize, key: []const u8, entry: Entry };

fn lessRow(_: void, a: SortRow, b: SortRow) bool {
    if (a.ord != b.ord) return a.ord < b.ord;
    return std.mem.lessThan(u8, a.key, b.key);
}

fn sortedEntries(allocator: std.mem.Allocator, rows: []SortRow) []Entry {
    std.sort.insertion(SortRow, rows, {}, lessRow);
    var out: std.ArrayListUnmanaged(Entry) = .empty;
    for (rows) |r| out.append(allocator, r.entry) catch oom();
    return out.items;
}

/// clap's `option_sort_key`: short flags first (lowercase before its uppercase),
/// then by long name, then unflagged args by id.
fn optionSortKey(allocator: std.mem.Allocator, a: *const Arg) []const u8 {
    if (a.short_char) |s| {
        return std.fmt.allocPrint(allocator, "{c}{c}", .{ std.ascii.toLower(s), if (std.ascii.isUpper(s)) @as(u8, '1') else '0' }) catch oom();
    }
    if (a.long_name) |l| return l;
    return std.fmt.allocPrint(allocator, "{{{s}", .{a.id}) catch oom();
}

fn argOrd(a: *const Arg) usize {
    return a.disp_ord orelse 999;
}

/// The order assigned to the synthetic `-V/--version` flag (one past help).
fn versionOrd(cmd: *const Command) usize {
    if (cmd.current_disp_ord) |c| return c + 1;
    return 999;
}

/// Sorted option rows for the default `Options:` section: visible unheaded
/// options plus the auto help/version flags, ordered by display order.
fn sortedOptionEntries(allocator: std.mem.Allocator, cmd: *const Command, include_headed: bool, long: bool) []Entry {
    var rows: std.ArrayListUnmanaged(SortRow) = .empty;
    for (cmd.arg_list.items) |*a| {
        if (a.isPositional() or !a.shownIn(long)) continue;
        if (!include_headed and a.help_heading != null) continue;
        rows.append(allocator, .{ .ord = argOrd(a), .key = optionSortKey(allocator, a), .entry = .{ .term = optionTerm(allocator, a), .help = argHelp(allocator, a) } }) catch oom();
    }
    if (!cmd.disable_help_flag) {
        const ht = if (hasLongHelp(cmd)) "Print help (see more with '--help')" else help_flag_help;
        rows.append(allocator, .{ .ord = cmd.builtinOrder(), .key = "h0", .entry = .{ .term = "-h, --help", .help = ht } }) catch oom();
    }
    if (cmd.hasVersionFlag()) {
        rows.append(allocator, .{ .ord = versionOrd(cmd), .key = "v1", .entry = .{ .term = "-V, --version", .help = "Print version" } }) catch oom();
    }
    return sortedEntries(allocator, rows.items);
}

/// Sorted subcommand rows (visible subcommands + the auto `help` entry).
fn sortedSubcommandEntries(allocator: std.mem.Allocator, cmd: *const Command) []Entry {
    var rows: std.ArrayListUnmanaged(SortRow) = .empty;
    for (cmd.subcommands.items) |*sc| {
        if (sc.is_hidden) continue;
        rows.append(allocator, .{ .ord = sc.disp_ord orelse 999, .key = sc.name, .entry = .{ .term = sc.name, .help = subcommandHelp(allocator, sc) } }) catch oom();
    }
    if (!cmd.disable_help_subcommand) {
        rows.append(allocator, .{ .ord = cmd.builtinOrder(), .key = "help", .entry = .{ .term = "help", .help = help_about } }) catch oom();
    }
    return sortedEntries(allocator, rows.items);
}

fn writeCommands(b: *Buf, cmd: *const Command) void {
    const entries = sortedSubcommandEntries(b.allocator, cmd);
    b.addByte('\n');
    b.add("Commands:\n");
    layout.table(b, 2, entries, cmd.term_width);
}

// ----- Arguments (positionals) -----

fn writeArguments(b: *Buf, cmd: *const Command) void {
    var entries: std.ArrayListUnmanaged(Entry) = .empty;
    collectPositionals(b.allocator, cmd, &entries);
    b.addByte('\n');
    b.add("Arguments:\n");
    layout.table(b, 2, entries.items, cmd.term_width);
}

fn collectPositionals(allocator: std.mem.Allocator, cmd: *const Command, entries: *std.ArrayListUnmanaged(Entry)) void {
    var i: usize = 1;
    while (cmd.getPositional(i)) |a| : (i += 1) {
        if (!a.shownIn(false) or a.help_heading != null) continue;
        entries.append(allocator, .{
            .term = layout.positionalNotationStr(allocator, a),
            .help = argHelp(allocator, a),
        }) catch oom();
    }
}

// ----- Options -----

fn writeOptions(b: *Buf, cmd: *const Command) void {
    // default `Options:` section: unheaded options plus the auto help/version flags
    const entries = sortedOptionEntries(b.allocator, cmd, false, false);
    if (entries.len != 0) {
        b.addByte('\n');
        b.add("Options:\n");
        layout.table(b, 2, entries, cmd.term_width);
    }
    writeHeadedSections(b, cmd);
}

/// One section per distinct `help_heading`, in first-appearance order. A section
/// holds both options and positionals assigned to that heading, each rendered by
/// its kind.
fn writeHeadedSections(b: *Buf, cmd: *const Command) void {
    var seen: std.ArrayListUnmanaged([]const u8) = .empty;
    for (cmd.arg_list.items) |*a| {
        const heading = a.help_heading orelse continue;
        if (!a.shownIn(false)) continue;
        if (containsStr(seen.items, heading)) continue;
        seen.append(b.allocator, heading) catch oom();

        var entries: std.ArrayListUnmanaged(Entry) = .empty;
        for (cmd.arg_list.items) |*x| {
            if (!x.shownIn(false)) continue;
            const h = x.help_heading orelse continue;
            if (!std.mem.eql(u8, h, heading)) continue;
            const term = if (x.isPositional()) layout.positionalNotationStr(b.allocator, x) else optionTerm(b.allocator, x);
            entries.append(b.allocator, .{ .term = term, .help = argHelp(b.allocator, x) }) catch oom();
        }
        b.addByte('\n');
        b.add(heading);
        b.add(":\n");
        layout.table(b, 2, entries.items, cmd.term_width);
    }
}

// ----- template section/row builders -----

/// `{all-args}`: Commands, Arguments, Options, and custom-heading sections,
/// separated by a blank line, with no leading or trailing blank (clap's
/// `write_all_args`).
fn writeAllArgs(b: *Buf, cmd: *const Command, long: bool) void {
    var sections: std.ArrayListUnmanaged([]const u8) = .empty;
    if (hasListedSubcommands(cmd)) sections.append(b.allocator, section(b.allocator, "Commands", tableStr(b.allocator, sortedSubcommandEntries(b.allocator, cmd), cmd.term_width))) catch oom();
    if (hasPositionals(cmd)) sections.append(b.allocator, section(b.allocator, "Arguments", positionalRows(b.allocator, cmd, long))) catch oom();
    const opts = optionRows(b.allocator, cmd, long);
    if (opts.len != 0) sections.append(b.allocator, section(b.allocator, "Options", opts)) catch oom();
    appendHeadingSections(b.allocator, cmd, &sections, long);
    for (sections.items, 0..) |s, i| {
        if (i != 0) b.add("\n\n");
        b.add(s);
    }
}

/// "Header:\n" + rows with the trailing newline trimmed (for joining).
fn section(allocator: std.mem.Allocator, header: []const u8, rows: []const u8) []const u8 {
    return std.fmt.allocPrint(allocator, "{s}:\n{s}", .{ header, std.mem.trimEnd(u8, rows, "\n") }) catch oom();
}

fn appendHeadingSections(allocator: std.mem.Allocator, cmd: *const Command, sections: *std.ArrayListUnmanaged([]const u8), long: bool) void {
    var seen: std.ArrayListUnmanaged([]const u8) = .empty;
    for (cmd.arg_list.items) |*a| {
        const heading = a.help_heading orelse continue;
        if (!a.shownIn(long) or containsStr(seen.items, heading)) continue;
        seen.append(allocator, heading) catch oom();
        var entries: std.ArrayListUnmanaged(Entry) = .empty;
        for (cmd.arg_list.items) |*x| {
            if (!x.shownIn(long)) continue;
            const h = x.help_heading orelse continue;
            if (!std.mem.eql(u8, h, heading)) continue;
            const term = if (x.isPositional()) layout.positionalNotationStr(allocator, x) else optionTerm(allocator, x);
            entries.append(allocator, .{ .term = term, .help = argHelp(allocator, x) }) catch oom();
        }
        sections.append(allocator, section(allocator, heading, tableStr(allocator, entries.items, cmd.term_width))) catch oom();
    }
}

/// `{options}` rows: every visible non-positional (incl. headed) plus the auto
/// help/version flags, sorted by display order.
fn optionRows(allocator: std.mem.Allocator, cmd: *const Command, long: bool) []const u8 {
    return tableStr(allocator, sortedOptionEntries(allocator, cmd, true, long), cmd.term_width);
}

fn positionalRows(allocator: std.mem.Allocator, cmd: *const Command, long: bool) []const u8 {
    var entries: std.ArrayListUnmanaged(Entry) = .empty;
    var i: usize = 1;
    while (cmd.getPositional(i)) |a| : (i += 1) {
        if (!a.shownIn(long)) continue;
        entries.append(allocator, .{ .term = layout.positionalNotationStr(allocator, a), .help = argHelp(allocator, a) }) catch oom();
    }
    return tableStr(allocator, entries.items, cmd.term_width);
}

fn subcommandRows(allocator: std.mem.Allocator, cmd: *const Command) []const u8 {
    return tableStr(allocator, sortedSubcommandEntries(allocator, cmd), cmd.term_width);
}

fn tableStr(allocator: std.mem.Allocator, entries: []const Entry, term_width: ?usize) []const u8 {
    var b = Buf{ .allocator = allocator };
    layout.table(&b, 2, entries, term_width);
    return b.items();
}

fn containsStr(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |h| {
        if (std.mem.eql(u8, h, needle)) return true;
    }
    return false;
}

fn collectOptions(allocator: std.mem.Allocator, cmd: *const Command, entries: *std.ArrayListUnmanaged(Entry)) void {
    for (cmd.arg_list.items) |*a| {
        if (a.isPositional() or a.is_hidden or a.help_heading != null) continue;
        entries.append(allocator, .{
            .term = optionTerm(allocator, a),
            .help = argHelp(allocator, a),
        }) catch oom();
    }
    if (!cmd.disable_help_flag) {
        const ht = if (hasLongHelp(cmd)) "Print help (see more with '--help')" else help_flag_help;
        entries.append(allocator, .{ .term = "-h, --help", .help = ht }) catch oom();
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
    if (a.effectiveNumArgs().min == 0) {
        // optional value: attached form with require_equals, else a spaced [<NAME>]
        if (a.require_equals) {
            b.add("[=<");
            b.add(name);
            b.add(">]");
        } else {
            b.add(" [<");
            b.add(name);
            b.add(">]");
        }
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
    appendVisibleAliases(&b, a);
    if (a.possibleValueNames(allocator)) |pv| {
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

/// Append `[aliases: -s, --long, ...]` from visible short then long aliases.
fn appendVisibleAliases(b: *Buf, a: *const Arg) void {
    const shorts = a.visible_short_aliases_list orelse "";
    const longs = a.visible_aliases_list orelse &[_][]const u8{};
    if (shorts.len == 0 and longs.len == 0) return;
    sep(b);
    b.add("[aliases: ");
    var first = true;
    for (shorts) |c| {
        if (!first) b.add(", ");
        b.add("-");
        b.addByte(c);
        first = false;
    }
    for (longs) |l| {
        if (!first) b.add(", ");
        b.add("--");
        b.add(l);
        first = false;
    }
    b.add("]");
}

fn sep(b: *Buf) void {
    if (b.items().len != 0) b.addByte(' ');
}

// ----- queries -----

fn hasListedSubcommands(cmd: *const Command) bool {
    // the synthetic `help` subcommand is only listed when there are visible ones
    return cmd.hasVisibleSubcommands();
}

fn hasPositionals(cmd: *const Command) bool {
    for (cmd.arg_list.items) |*a| {
        if (a.isPositional() and !a.is_hidden and a.help_heading == null) return true;
    }
    return false;
}
