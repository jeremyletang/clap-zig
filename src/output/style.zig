const std = @import("std");

/// When to emit ANSI styling. Port of clap's `ColorChoice`.
/// https://github.com/clap-rs/clap/blob/master/clap_builder/src/util/color.rs
pub const ColorChoice = enum { auto, always, never };

/// The semantic roles the help/usage/error builders tag spans with. The builders
/// reference only these — never escape sequences — so colour logic stays here.
pub const Role = enum { header, usage, literal, placeholder, err, valid, invalid, context };

/// SGR escape prefix for one role; reset is always `\x1b[0m`. Empty prefix = no
/// styling. anstyle emits one escape per effect, then the fg colour.
const Style = struct {
    open: []const u8 = "",

    fn wrap(self: Style, allocator: std.mem.Allocator, text: []const u8) []const u8 {
        if (self.open.len == 0 or text.len == 0) return text;
        return std.fmt.allocPrint(allocator, "{s}{s}\x1b[0m", .{ self.open, text }) catch @panic("clap: OOM styling");
    }
};

/// Per-role styling. `plain()` emits no escapes (byte-identical to unstyled
/// output); `styled()` is clap's default palette. Port of clap's `Styles`.
pub const Styles = struct {
    header: Style = .{},
    usage: Style = .{},
    literal: Style = .{},
    placeholder: Style = .{},
    err: Style = .{},
    valid: Style = .{},
    invalid: Style = .{},
    context: Style = .{},

    pub fn plain() Styles {
        return .{};
    }

    /// clap defaults: header/usage bold+underline, literal bold, error red+bold,
    /// valid green, invalid yellow, placeholder/context unstyled.
    pub fn styled() Styles {
        return .{
            .header = .{ .open = "\x1b[1m\x1b[4m" },
            .usage = .{ .open = "\x1b[1m\x1b[4m" },
            .literal = .{ .open = "\x1b[1m" },
            .placeholder = .{},
            .err = .{ .open = "\x1b[1m\x1b[31m" },
            .valid = .{ .open = "\x1b[32m" },
            .invalid = .{ .open = "\x1b[33m" },
            .context = .{},
        };
    }

    pub fn wrap(self: *const Styles, allocator: std.mem.Allocator, role: Role, text: []const u8) []const u8 {
        return self.styleFor(role).wrap(allocator, text);
    }

    fn styleFor(self: *const Styles, role: Role) Style {
        return switch (role) {
            .header => self.header,
            .usage => self.usage,
            .literal => self.literal,
            .placeholder => self.placeholder,
            .err => self.err,
            .valid => self.valid,
            .invalid => self.invalid,
            .context => self.context,
        };
    }
};

/// The styles in effect for the current render, or null when output is plain.
/// Set by the render entry points for the duration of one render call (CLI help
/// rendering is one-shot and single-threaded, so a scoped global keeps the
/// builders free of colour parameters).
var active: ?*const Styles = null;

pub fn setActive(s: ?*const Styles) void {
    active = s;
}

/// Wrap `text` for `role` using the render-scoped active styles, or return it
/// plain when no render is styling. This is how `layout.Buf.role` stays
/// colour-agnostic — it just asks here.
pub fn applyActive(allocator: std.mem.Allocator, role: Role, text: []const u8) []const u8 {
    if (active) |st| return st.wrap(allocator, role, text);
    return text;
}

/// Resolve whether to emit colour, per `cli_policies.txt`: `always`/`never` are
/// absolute; `auto` is forced by `CLICOLOR_FORCE`, else disabled by `NO_COLOR`,
/// `TERM=dumb`, or a non-tty stdout. The caller supplies the env/tty facts so the
/// library stays IO-free.
pub fn enabled(choice: ColorChoice, no_color: bool, clicolor_force: bool, term: ?[]const u8, is_tty: bool) bool {
    return switch (choice) {
        .never => false,
        .always => true,
        .auto => blk: {
            if (clicolor_force) break :blk true;
            if (no_color) break :blk false;
            if (term) |t| {
                if (std.mem.eql(u8, t, "dumb")) break :blk false;
            }
            break :blk is_tty;
        },
    };
}

test "enabled policy" {
    const t = std.testing;
    try t.expect(!enabled(.never, false, true, null, true));
    try t.expect(enabled(.always, true, false, "dumb", false));
    try t.expect(enabled(.auto, false, false, null, true));
    try t.expect(!enabled(.auto, false, false, null, false));
    try t.expect(!enabled(.auto, true, false, null, true));
    try t.expect(!enabled(.auto, false, false, "dumb", true));
    try t.expect(enabled(.auto, true, true, "dumb", false)); // CLICOLOR_FORCE wins
}

test "styled wrap / plain" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const s = Styles.styled();
    try t.expectEqualStrings("\x1b[1m\x1b[4mUsage:\x1b[0m", s.wrap(a, .header, "Usage:"));
    try t.expectEqualStrings("\x1b[1mfoo\x1b[0m", s.wrap(a, .literal, "foo"));
    try t.expectEqualStrings("x", s.wrap(a, .placeholder, "x")); // unstyled role
    const p = Styles.plain();
    try t.expectEqualStrings("Usage:", p.wrap(a, .header, "Usage:")); // plain = no escapes
}
