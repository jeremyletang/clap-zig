const std = @import("std");
const action = @import("action.zig");
const range = @import("range.zig");

// aliased because the `action` builder method below shadows the import inside the struct
const ArgAction = action.ArgAction;

/// A single command-line argument: a flag, an option, or a positional.
/// Port of clap's `Arg`
/// (https://github.com/clap-rs/clap/blob/master/clap_builder/src/builder/arg.rs). Construction is
/// allocation-free; the owning `Command` holds the allocator.
pub const Arg = struct {
    id: []const u8 = "",
    short_char: ?u8 = null,
    long_name: ?[]const u8 = null,
    help_str: ?[]const u8 = null,
    value_name: ?[]const u8 = null,
    action_val: ArgAction = .set,
    num_args: ?range.ValueRange = null,
    // positional index (1-based); assigned by `Command` when added. null = flag/option.
    index: ?usize = null,
    required_flag: bool = false,
    last_flag: bool = false,
    require_equals: bool = false,
    default_value: ?[]const u8 = null,
    default_missing_value: ?[]const u8 = null,
    possible_values: ?[]const []const u8 = null,

    pub fn new(id: []const u8) Arg {
        return .{ .id = id };
    }

    // ----- builder setters (return a copy, clap-style chaining) -----

    pub fn short(self: Arg, c: u8) Arg {
        var a = self;
        a.short_char = c;
        return a;
    }

    pub fn long(self: Arg, name: []const u8) Arg {
        var a = self;
        a.long_name = name;
        if (a.id.len == 0) a.id = name;
        return a;
    }

    pub fn help(self: Arg, text: []const u8) Arg {
        var a = self;
        a.help_str = text;
        return a;
    }

    pub fn valueName(self: Arg, name: []const u8) Arg {
        var a = self;
        a.value_name = name;
        a.action_val = .set;
        if (a.id.len == 0) a.id = name;
        return a;
    }

    pub fn action(self: Arg, kind: ArgAction) Arg {
        var a = self;
        a.action_val = kind;
        return a;
    }

    pub fn numArgs(self: Arg, r: range.ValueRange) Arg {
        var a = self;
        a.num_args = r;
        return a;
    }

    pub fn required(self: Arg, yes: bool) Arg {
        var a = self;
        a.required_flag = yes;
        return a;
    }

    pub fn last(self: Arg, yes: bool) Arg {
        var a = self;
        a.last_flag = yes;
        return a;
    }

    pub fn requireEquals(self: Arg, yes: bool) Arg {
        var a = self;
        a.require_equals = yes;
        return a;
    }

    pub fn defaultValue(self: Arg, v: []const u8) Arg {
        var a = self;
        a.default_value = v;
        return a;
    }

    pub fn defaultMissingValue(self: Arg, v: []const u8) Arg {
        var a = self;
        a.default_missing_value = v;
        return a;
    }

    /// Restrict the accepted values to an enumerated set (clap's
    /// `value_parser([..])` / `PossibleValuesParser`).
    pub fn valueParser(self: Arg, values: []const []const u8) Arg {
        var a = self;
        a.possible_values = values;
        return a;
    }

    // ----- queries -----

    pub fn isPositional(self: Arg) bool {
        return self.short_char == null and self.long_name == null;
    }

    pub fn takesValue(self: Arg) bool {
        return self.effectiveNumArgs().takesValues();
    }

    pub fn effectiveNumArgs(self: Arg) range.ValueRange {
        return self.num_args orelse range.ValueRange.forAction(self.action_val);
    }

    pub fn isMultiple(self: Arg) bool {
        return self.action_val == .append or self.action_val == .count or self.effectiveNumArgs().isMultiple();
    }

    // ----- usage-string constructor (mirrors clap's `arg!`) -----

    /// Build an `Arg` from a usage string plus optional help, mirroring the
    /// subset of clap's `arg!` macro: `[name:] [-s] [--long] [<VAL>|[VAL]] [...]`.
    /// See https://github.com/clap-rs/clap/blob/master/clap_builder/src/macros.rs#L164-L561
    pub fn fromUsage(usage: []const u8, help_text: ?[]const u8) Arg {
        var a = Arg{};
        if (help_text) |h| a.help_str = h;
        var it = std.mem.tokenizeScalar(u8, usage, ' ');
        var first = true;
        while (it.next()) |tok| {
            if (first and isExplicitName(tok)) {
                a.id = tok[0 .. tok.len - 1];
            } else {
                a.applyUsageToken(tok);
            }
            first = false;
        }
        return a;
    }

    fn isExplicitName(tok: []const u8) bool {
        if (tok.len < 2 or tok[tok.len - 1] != ':') return false;
        for (tok[0 .. tok.len - 1]) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') return false;
        }
        return true;
    }

    fn applyUsageToken(self: *Arg, tok: []const u8) void {
        if (std.mem.eql(u8, tok, "...")) {
            self.applyVariadic();
        } else if (tok.len > 3 and std.mem.endsWith(u8, tok, "...")) {
            // `...` attached to the value notation, e.g. `<PATH>...`
            self.applyUsageToken(tok[0 .. tok.len - 3]);
            self.applyVariadic();
        } else if (std.mem.startsWith(u8, tok, "--")) {
            self.long_name = tok[2..];
            if (self.id.len == 0) self.id = tok[2..];
            if (self.value_name == null) self.action_val = .set_true;
        } else if (tok.len == 2 and tok[0] == '-') {
            self.short_char = tok[1];
            if (self.value_name == null) self.action_val = .set_true;
        } else if (wrapped(tok, '<', '>')) |name| {
            self.applyValueName(name, true);
        } else if (wrapped(tok, '[', ']')) |name| {
            self.applyValueName(name, false);
        }
    }

    fn applyValueName(self: *Arg, name: []const u8, req: bool) void {
        self.value_name = name;
        self.action_val = .set;
        if (self.id.len == 0) self.id = name;
        if (self.isPositional()) {
            self.required_flag = req;
        } else if (!req) {
            // optional value on a flag (`--color [WHEN]`)
            self.num_args = range.ValueRange.between(0, 1);
        }
    }

    fn applyVariadic(self: *Arg) void {
        if (self.action_val == .set) {
            if (self.isPositional()) self.num_args = range.ValueRange.atLeast(1);
            self.action_val = .append;
        } else if (self.action_val == .set_true) {
            self.action_val = .count;
        }
    }

    fn wrapped(tok: []const u8, open: u8, close: u8) ?[]const u8 {
        if (tok.len >= 2 and tok[0] == open and tok[tok.len - 1] == close) {
            return tok[1 .. tok.len - 1];
        }
        return null;
    }
};

const testing = std.testing;

test "fromUsage: required positional" {
    const a = Arg.fromUsage("<REMOTE>", "The remote to clone");
    try testing.expectEqualStrings("REMOTE", a.id);
    try testing.expectEqualStrings("REMOTE", a.value_name.?);
    try testing.expect(a.isPositional());
    try testing.expect(a.required_flag);
    try testing.expectEqual(action.ArgAction.set, a.action_val);
    try testing.expectEqualStrings("The remote to clone", a.help_str.?);
}

test "fromUsage: optional positional with explicit name" {
    const a = Arg.fromUsage("base: [COMMIT]", null);
    try testing.expectEqualStrings("base", a.id);
    try testing.expectEqualStrings("COMMIT", a.value_name.?);
    try testing.expect(a.isPositional());
    try testing.expect(!a.required_flag);
}

test "fromUsage: long option with value" {
    const a = Arg.fromUsage("--color <WHEN>", null);
    try testing.expectEqualStrings("color", a.id);
    try testing.expectEqualStrings("color", a.long_name.?);
    try testing.expectEqualStrings("WHEN", a.value_name.?);
    try testing.expect(!a.isPositional());
    try testing.expect(!a.required_flag);
    try testing.expectEqual(action.ArgAction.set, a.action_val);
}

test "fromUsage: short and long with value" {
    const a = Arg.fromUsage("-m --message <MESSAGE>", null);
    try testing.expectEqual(@as(?u8, 'm'), a.short_char);
    try testing.expectEqualStrings("message", a.long_name.?);
    try testing.expectEqualStrings("message", a.id);
    try testing.expectEqualStrings("MESSAGE", a.value_name.?);
}

test "fromUsage: variadic positional" {
    const a = Arg.fromUsage("<PATH>...", "Stuff to add");
    try testing.expectEqualStrings("PATH", a.id);
    try testing.expect(a.required_flag);
    try testing.expectEqual(action.ArgAction.append, a.action_val);
    try testing.expect(a.isMultiple());
    try testing.expectEqual(@as(usize, 1), a.effectiveNumArgs().min);
}

test "fromUsage: bare flag" {
    const a = Arg.fromUsage("-d --debug", null);
    try testing.expectEqual(@as(?u8, 'd'), a.short_char);
    try testing.expectEqualStrings("debug", a.long_name.?);
    try testing.expectEqual(action.ArgAction.set_true, a.action_val);
    try testing.expect(!a.takesValue());
}

test "builder: optional value via numArgs" {
    const a = Arg.new("color").long("color").valueName("WHEN")
        .valueParser(&.{ "always", "auto", "never" })
        .numArgs(range.ValueRange.between(0, 1))
        .requireEquals(true)
        .defaultValue("auto")
        .defaultMissingValue("always");
    try testing.expectEqualStrings("color", a.id);
    try testing.expectEqual(@as(usize, 0), a.num_args.?.min);
    try testing.expectEqual(@as(usize, 1), a.num_args.?.max);
    try testing.expect(a.require_equals);
    try testing.expectEqualStrings("auto", a.default_value.?);
    try testing.expectEqualStrings("always", a.default_missing_value.?);
    try testing.expectEqual(@as(usize, 3), a.possible_values.?.len);
}
