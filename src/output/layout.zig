const std = @import("std");
const arg = @import("../builder/arg.zig");
const command = @import("../builder/command.zig");
const style = @import("style.zig");

const Arg = arg.Arg;
const Command = command.Command;

/// Small append-only string builder for help/usage/error rendering. Allocates
/// from the supplied (arena) allocator and panics on failure, matching the rest
/// of the builder; output is produced once, just before exit. The role methods
/// wrap their text in ANSI escapes when a render is styling (see
/// `style.setActive`); otherwise they append plain text, so output is
/// byte-identical to the unstyled path.
pub const Buf = struct {
    allocator: std.mem.Allocator,
    list: std.ArrayListUnmanaged(u8) = .empty,

    pub fn add(self: *Buf, s: []const u8) void {
        self.list.appendSlice(self.allocator, s) catch oom();
    }

    pub fn addByte(self: *Buf, c: u8) void {
        self.list.append(self.allocator, c) catch oom();
    }

    pub fn spaces(self: *Buf, n: usize) void {
        self.list.appendNTimes(self.allocator, ' ', n) catch oom();
    }

    pub fn print(self: *Buf, comptime fmt: []const u8, args: anytype) void {
        const s = std.fmt.allocPrint(self.allocator, fmt, args) catch oom();
        self.add(s);
    }

    /// Append `s` styled for `role` (plain when no render is styling).
    pub fn role(self: *Buf, r: style.Role, s: []const u8) void {
        self.add(style.applyActive(self.allocator, r, s));
    }

    pub fn items(self: *const Buf) []const u8 {
        return self.list.items;
    }
};

/// Display width of `s` in columns, skipping ANSI SGR escape sequences
/// (`\x1b[ … m`). Equals `s.len` when there are no escapes, so plain layout math
/// is unchanged.
pub fn displayWidth(s: []const u8) usize {
    var w: usize = 0;
    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == 0x1b and i + 1 < s.len and s[i + 1] == '[') {
            i += 2;
            while (i < s.len and s[i] != 'm') i += 1;
            if (i < s.len) i += 1; // consume the 'm'
            continue;
        }
        w += 1;
        i += 1;
    }
    return w;
}

fn oom() noreturn {
    @panic("clap: OOM rendering output");
}

/// One row of a two-column help table.
pub const Entry = struct { term: []const u8, help: []const u8 };

/// Render a left-aligned two-column table: `indent` spaces, the term padded to
/// the widest term, two separator spaces, then the help. Trailing spaces are
/// emitted when help is empty, matching clap's output byte-for-byte. When
/// `term_width` is set (>0), the help column word-wraps to fit it, continuation
/// lines aligned under the help column.
/// Render-scoped flag (clap's `next_line_help`): force every row's help onto the
/// next line regardless of the auto-wrap heuristic. Set by `help.render`.
pub var force_next_line: bool = false;

pub fn table(buf: *Buf, indent: usize, entries: []const Entry, term_width: ?usize) void {
    var width: usize = 0;
    for (entries) |e| width = @max(width, displayWidth(e.term));
    if (force_next_line) return tableNextLine(buf, indent, entries, term_width orelse std.math.maxInt(usize));
    if (term_width) |tw| {
        if (willWrapNextLine(entries, width, tw)) return tableNextLine(buf, indent, entries, tw);
    }
    const offset = indent + width + 2; // where the help column starts
    for (entries) |e| {
        buf.spaces(indent);
        buf.add(e.term);
        buf.spaces(width - displayWidth(e.term) + 2);
        buf.add(wrapHelp(buf.allocator, e.help, term_width, offset));
        buf.addByte('\n');
    }
}

/// clap's `will_args_wrap`: when the term column would take >40% of the width and
/// some help would not fit beside it, the whole section drops to a next-line
/// layout (term on its own line, help indented beneath).
fn willWrapNextLine(entries: []const Entry, width: usize, tw: usize) bool {
    const taken = width + 4; // longest term + TAB_WIDTH*2
    if (tw < taken or taken * 100 <= tw * 40) return false;
    const avail = tw - taken;
    for (entries) |e| {
        if (displayWidth(e.help) > avail) return true;
    }
    return false;
}

/// Next-line layout: `indent` + term, then help wrapped under a fixed 10-column
/// indent (TAB + NEXT_LINE_INDENT). No blank line between entries (that only
/// happens in `--help` long mode).
fn tableNextLine(buf: *Buf, indent: usize, entries: []const Entry, tw: usize) void {
    const help_indent = indent + 8;
    for (entries) |e| {
        buf.spaces(indent);
        buf.add(e.term);
        buf.addByte('\n');
        buf.spaces(help_indent);
        buf.add(wrapHelp(buf.allocator, e.help, tw, help_indent));
        buf.addByte('\n');
    }
}

/// Word-wrap `help` to `term_width - offset` columns. Greedy word wrap that
/// preserves the original inter-word whitespace (only the gap at a break point is
/// replaced by the newline + indent), honors explicit newlines as hard breaks,
/// and re-applies each source line's own leading indentation to its wrapped
/// continuations. With no `term_width` (or 0/too-narrow) there is no wrapping,
/// but explicit newlines are still re-indented under the help column. Port of
/// clap's textwrap.
pub fn wrapHelp(allocator: std.mem.Allocator, help: []const u8, term_width: ?usize, offset: usize) []const u8 {
    if (help.len == 0) return help;
    const avail: usize = blk: {
        if (term_width) |tw| {
            if (tw != 0 and tw > offset) break :blk tw - offset;
        }
        break :blk std.math.maxInt(usize);
    };
    // fast path: single line with no wrapping needed
    if (avail == std.math.maxInt(usize) and std.mem.indexOfScalar(u8, help, '\n') == null) return help;

    var out: std.ArrayListUnmanaged(u8) = .empty;
    var lines = std.mem.splitScalar(u8, std.mem.trimEnd(u8, help, " \n"), '\n');
    var first_line = true;
    while (lines.next()) |line| {
        if (!first_line) newlineIndent(allocator, &out, offset);
        first_line = false;
        wrapLine(allocator, &out, line, avail, offset);
    }
    return out.items;
}

/// Wrap one source line; its leading whitespace becomes the continuation indent
/// (added on top of `offset`).
fn wrapLine(allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), line: []const u8, avail: usize, offset: usize) void {
    var lead: usize = 0;
    while (lead < line.len and line[lead] == ' ') lead += 1;
    out.appendSlice(allocator, line[0..lead]) catch oom();
    var col = lead; // columns used in the help area (relative to `offset`)
    var i = lead;
    var first_word = true;
    while (i < line.len) {
        const g = i;
        while (i < line.len and line[i] == ' ') i += 1;
        const gap = line[g..i];
        const w = i;
        while (i < line.len and line[i] != ' ') i += 1;
        const word = line[w..i];
        if (word.len == 0) break; // trailing spaces
        if (first_word) {
            out.appendSlice(allocator, word) catch oom();
            col += word.len;
        } else if (col + gap.len + word.len > avail) {
            newlineIndent(allocator, out, offset + lead);
            col = lead;
            out.appendSlice(allocator, word) catch oom();
            col += word.len;
        } else {
            out.appendSlice(allocator, gap) catch oom();
            out.appendSlice(allocator, word) catch oom();
            col += gap.len + word.len;
        }
        first_word = false;
    }
}

fn newlineIndent(allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), offset: usize) void {
    out.append(allocator, '\n') catch oom();
    out.appendNTimes(allocator, ' ', offset) catch oom();
}

/// The value notation for a positional as shown in usage / the Arguments table:
/// `<NAME>` (required) or `[NAME]` (optional), with a trailing `...` if variadic.
pub fn positionalNotation(buf: *Buf, a: *const Arg) void {
    const r = a.effectiveNumArgs();
    const open = if (a.required_flag) "<" else "[";
    const close = if (a.required_flag) ">" else "]";
    const name = a.value_name orelse a.id;
    // a fixed-count positional repeats its slot (`[pos] [pos] [pos]`); a bounded
    // range or unbounded one shows a single slot with a trailing `...`
    const reps = if (a.action_val == .append or a.action_val == .count) 1 else @max(r.min, 1);
    var i: usize = 0;
    while (i < reps) : (i += 1) {
        if (i > 0) buf.addByte(' ');
        buf.add(open);
        buf.add(name);
        buf.add(close);
    }
    if (a.showsEllipsis() or r.max > r.min) buf.add("...");
}

pub fn positionalNotationStr(allocator: std.mem.Allocator, a: *const Arg) []const u8 {
    var b = Buf{ .allocator = allocator };
    positionalNotation(&b, a);
    return b.items();
}

/// How an argument is named in a conflict message: its flag/value form plus a
/// trailing `...` when it accepts multiple (clap's Arg display in conflicts).
pub fn conflictDisplay(allocator: std.mem.Allocator, a: *const Arg) []const u8 {
    const base = argUsageStr(allocator, a);
    if (!a.showsEllipsis()) return base;
    return std.fmt.allocPrint(allocator, "{s}...", .{base}) catch @panic("clap: OOM");
}

/// How an argument is referred to in error messages: `<MODE>` / `[PORT]` for
/// positionals, `--name <VAL>` / `-n <VAL>` for options/flags.
pub fn argUsageStr(allocator: std.mem.Allocator, a: *const Arg) []const u8 {
    if (a.isPositional()) return positionalNotationStr(allocator, a);
    var b = Buf{ .allocator = allocator };
    if (a.long_name) |l| {
        b.role(.literal, std.fmt.allocPrint(allocator, "--{s}", .{l}) catch oom());
    } else if (a.short_char) |c| {
        b.role(.literal, std.fmt.allocPrint(allocator, "-{c}", .{c}) catch oom());
    }
    if (a.takesValue()) {
        if (a.value_names) |names| {
            if (names.len > 1) {
                for (names) |n| {
                    b.add(" <");
                    b.add(n);
                    b.add(">");
                }
                return b.items();
            }
        }
        b.add(" <");
        b.add(a.value_name orelse a.id);
        b.add(">");
    }
    return b.items();
}

/// How an argument appears inside a group token: a bare value name for a
/// positional (`INPUT_FILE`), otherwise its option usage (`--major`, `--spec-in <SPEC_IN>`).
pub fn memberNotation(allocator: std.mem.Allocator, a: *const Arg) []const u8 {
    if (a.isPositional()) return a.value_name orelse a.id;
    return argUsageStr(allocator, a);
}

/// A group as shown in usage / errors: `<member1|member2|...>` in definition order.
pub fn groupNotation(allocator: std.mem.Allocator, cmd: *const Command, id: []const u8) []const u8 {
    var b = Buf{ .allocator = allocator };
    b.add("<");
    var first = true;
    for (cmd.arg_list.items) |*a| {
        if (!cmd.argInGroupId(a, id)) continue;
        if (!first) b.add("|");
        b.add(memberNotation(allocator, a));
        first = false;
    }
    b.add(">");
    return b.items();
}
