const std = @import("std");
const arg = @import("../builder/arg.zig");
const command = @import("../builder/command.zig");

const Arg = arg.Arg;
const Command = command.Command;

/// Small append-only string builder for help/usage/error rendering. Allocates
/// from the supplied (arena) allocator and panics on failure, matching the rest
/// of the builder; output is produced once, just before exit.
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

    pub fn items(self: *const Buf) []const u8 {
        return self.list.items;
    }
};

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
pub fn table(buf: *Buf, indent: usize, entries: []const Entry, term_width: ?usize) void {
    var width: usize = 0;
    for (entries) |e| width = @max(width, e.term.len);
    const offset = indent + width + 2; // where the help column starts
    for (entries) |e| {
        buf.spaces(indent);
        buf.add(e.term);
        buf.spaces(width - e.term.len + 2);
        buf.add(wrapHelp(buf.allocator, e.help, term_width, offset));
        buf.addByte('\n');
    }
}

/// Word-wrap `help` to `term_width - offset` columns, prefixing continuation
/// lines with `offset` spaces; honors explicit newlines as hard breaks. No
/// wrapping when `term_width` is null or <= offset. Port of clap's textwrap.
fn wrapHelp(allocator: std.mem.Allocator, help: []const u8, term_width: ?usize, offset: usize) []const u8 {
    const tw = term_width orelse return help;
    if (tw == 0 or tw <= offset or help.len == 0) return help;
    const avail = tw - offset;

    var out: std.ArrayListUnmanaged(u8) = .empty;
    var col: usize = 0; // columns used on the current output line
    var first_word = true;
    var lines = std.mem.splitScalar(u8, help, '\n');
    var first_line = true;
    while (lines.next()) |line| {
        if (!first_line) {
            newlineIndent(allocator, &out, offset);
            col = 0;
            first_word = true;
        }
        first_line = false;
        var words = std.mem.tokenizeScalar(u8, line, ' ');
        while (words.next()) |word| {
            if (!first_word and col + 1 + word.len > avail) {
                newlineIndent(allocator, &out, offset);
                col = 0;
                first_word = true;
            }
            if (!first_word) {
                out.append(allocator, ' ') catch oom();
                col += 1;
            }
            out.appendSlice(allocator, word) catch oom();
            col += word.len;
            first_word = false;
        }
    }
    return out.items;
}

fn newlineIndent(allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), offset: usize) void {
    out.append(allocator, '\n') catch oom();
    out.appendNTimes(allocator, ' ', offset) catch oom();
}

/// The value notation for a positional as shown in usage / the Arguments table:
/// `<NAME>` (required) or `[NAME]` (optional), with a trailing `...` if variadic.
pub fn positionalNotation(buf: *Buf, a: *const Arg) void {
    buf.add(if (a.required_flag) "<" else "[");
    buf.add(a.value_name orelse a.id);
    buf.add(if (a.required_flag) ">" else "]");
    if (a.isMultiple()) buf.add("...");
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
    if (!a.isMultiple()) return base;
    return std.fmt.allocPrint(allocator, "{s}...", .{base}) catch @panic("clap: OOM");
}

/// How an argument is referred to in error messages: `<MODE>` / `[PORT]` for
/// positionals, `--name <VAL>` / `-n <VAL>` for options/flags.
pub fn argUsageStr(allocator: std.mem.Allocator, a: *const Arg) []const u8 {
    if (a.isPositional()) return positionalNotationStr(allocator, a);
    var b = Buf{ .allocator = allocator };
    if (a.long_name) |l| {
        b.add("--");
        b.add(l);
    } else if (a.short_char) |c| {
        b.addByte('-');
        b.addByte(c);
    }
    if (a.takesValue()) {
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
