const std = @import("std");
const action = @import("action.zig");
const range = @import("range.zig");
const value_parser = @import("value_parser.zig");
const possible_value = @import("possible_value.zig");

const PossibleValue = possible_value.PossibleValue;

/// A conditional requirement: when the owning arg holds `value`, `target` also
/// becomes required. Mirrors the Equals-predicate entries of clap's `requires`
/// (`requires_if` / `requires_ifs`).
pub const RequireIf = struct {
    value: []const u8,
    target: []const u8,
};

/// A conditional default: when arg `arg` matches the predicate, the owning arg
/// defaults to `value` (or, if `value` is null, gets no default at all). The
/// predicate is "present" when `equals` is null, else "equals that string".
/// Mirrors clap's `default_value_if(s)` / `default_values_if(s)`.
pub const DefaultValueIf = struct {
    arg: []const u8,
    equals: ?[]const u8 = null,
    value: ?[]const []const u8 = null,
};

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
    long_help_str: ?[]const u8 = null,
    aliases_list: ?[]const []const u8 = null,
    visible_aliases_list: ?[]const []const u8 = null,
    short_aliases_list: ?[]const u8 = null,
    visible_short_aliases_list: ?[]const u8 = null,
    help_str: ?[]const u8 = null,
    value_name: ?[]const u8 = null,
    action_val: ArgAction = .set,
    num_args: ?range.ValueRange = null,
    value_delimiter: ?u8 = null,
    /// a token that ends value collection for this arg (clap's `value_terminator`)
    value_terminator: ?[]const u8 = null,
    /// once this (variadic) positional starts collecting, every later token —
    /// flags, `--`, hyphen values — is a literal value (clap's `trailing_var_arg`)
    trailing_var_arg: bool = false,
    /// help section heading (null = the default `Options:` section). `*_set`
    /// distinguishes "explicitly set" (incl. to null) from "inherit the
    /// command's current `next_help_heading`".
    help_heading: ?[]const u8 = null,
    help_heading_set: bool = false,
    /// help sort order; null → 999 (clap's `display_order`). Auto-assigned in
    /// definition order by the owning command unless set explicitly.
    disp_ord: ?usize = null,
    // positional index (1-based); assigned by `Command` when added. null = flag/option.
    index: ?usize = null,
    required_flag: bool = false,
    last_flag: bool = false,
    require_equals: bool = false,
    default_value: ?[]const u8 = null,
    default_values: ?[]const []const u8 = null,
    default_missing_value: ?[]const u8 = null,
    env_var: ?[]const u8 = null,
    possible_values: ?[]const []const u8 = null,
    value_parser_fn: ?value_parser.ParserFn = null,
    value_help: ?[]const PossibleValue = null,
    value_names: ?[]const []const u8 = null,
    group_id: ?[]const u8 = null,
    requires_id: ?[]const u8 = null,
    requires_ifs: ?[]const RequireIf = null,
    required_unless_any: ?[]const []const u8 = null,
    required_unless_all: ?[]const []const u8 = null,
    required_if_eq_any: ?[]const RequireIf = null,
    required_if_eq_all: ?[]const RequireIf = null,
    default_value_ifs: ?[]const DefaultValueIf = null,
    conflicts_with: ?[]const []const u8 = null,
    overrides: ?[]const []const u8 = null,
    is_exclusive: bool = false,
    is_global: bool = false,
    allow_hyphen_values: bool = false,
    allow_negative_numbers: bool = false,
    is_hidden: bool = false,
    hide_short_help: bool = false,
    hide_long_help: bool = false,

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

    /// Hidden long aliases that also match this arg (clap's `alias`/`aliases`).
    pub fn aliases(self: Arg, names: []const []const u8) Arg {
        var a = self;
        a.aliases_list = names;
        return a;
    }

    /// Long aliases that match this arg and are shown in help (clap's
    /// `visible_alias`/`visible_aliases`).
    pub fn visibleAliases(self: Arg, names: []const []const u8) Arg {
        var a = self;
        a.visible_aliases_list = names;
        return a;
    }

    /// Hidden short aliases that also match this arg (clap's `short_alias(es)`).
    pub fn shortAliases(self: Arg, chars: []const u8) Arg {
        var a = self;
        a.short_aliases_list = chars;
        return a;
    }

    /// Short aliases shown in help (clap's `visible_short_alias(es)`).
    pub fn visibleShortAliases(self: Arg, chars: []const u8) Arg {
        var a = self;
        a.visible_short_aliases_list = chars;
        return a;
    }

    /// Whether `name` matches this arg's long name or any of its aliases.
    pub fn matchesLong(self: *const Arg, name: []const u8) bool {
        if (self.long_name) |l| {
            if (std.mem.eql(u8, l, name)) return true;
        }
        if (self.aliases_list) |al| {
            for (al) |x| if (std.mem.eql(u8, x, name)) return true;
        }
        if (self.visible_aliases_list) |al| {
            for (al) |x| if (std.mem.eql(u8, x, name)) return true;
        }
        return false;
    }

    /// Whether `prefix` is a prefix of this arg's long name or any of its long
    /// aliases (clap's `infer_long_args` prefix matching).
    pub fn anyLongStartsWith(self: *const Arg, prefix: []const u8) bool {
        if (self.long_name) |l| {
            if (std.mem.startsWith(u8, l, prefix)) return true;
        }
        if (self.aliases_list) |al| {
            for (al) |x| if (std.mem.startsWith(u8, x, prefix)) return true;
        }
        if (self.visible_aliases_list) |al| {
            for (al) |x| if (std.mem.startsWith(u8, x, prefix)) return true;
        }
        return false;
    }

    /// Whether `c` matches this arg's short flag or any of its short aliases.
    pub fn matchesShort(self: *const Arg, c: u8) bool {
        if (self.short_char == c) return true;
        if (self.short_aliases_list) |al| {
            for (al) |x| if (x == c) return true;
        }
        if (self.visible_short_aliases_list) |al| {
            for (al) |x| if (x == c) return true;
        }
        return false;
    }

    pub fn help(self: Arg, text: []const u8) Arg {
        var a = self;
        a.help_str = text;
        return a;
    }

    /// Longer help shown only in `--help` (clap's `long_help`).
    pub fn longHelp(self: Arg, text: []const u8) Arg {
        var a = self;
        a.long_help_str = text;
        return a;
    }

    /// The help text for the given mode: `--help` prefers long help, `-h` prefers
    /// short help, each falling back to the other (clap's about selection).
    pub fn helpFor(self: *const Arg, for_long: bool) ?[]const u8 {
        if (for_long) return self.long_help_str orelse self.help_str;
        return self.help_str orelse self.long_help_str;
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

    /// Multiple default values used when the arg is absent (clap's `default_values`).
    pub fn defaultValues(self: Arg, vals: []const []const u8) Arg {
        var a = self;
        a.default_values = vals;
        return a;
    }

    /// Fall back to the named environment variable when the arg is absent from
    /// the command line (clap's `env`). The value is supplied by an `EnvSource`
    /// passed to `getMatchesEnv`; precedence is CLI > env > default.
    pub fn env(self: Arg, name: []const u8) Arg {
        var a = self;
        a.env_var = name;
        return a;
    }

    /// Split each supplied value on this byte into separate values (clap's
    /// `value_delimiter`).
    pub fn valueDelimiter(self: Arg, c: u8) Arg {
        var a = self;
        a.value_delimiter = c;
        return a;
    }

    /// A token that ends value collection for this arg; it is consumed but not
    /// stored, and following tokens fill later args (clap's `value_terminator`).
    pub fn valueTerminator(self: Arg, term: []const u8) Arg {
        var a = self;
        a.value_terminator = term;
        return a;
    }

    /// Treat every token after this positional's first value as a literal value,
    /// including flags and `--` (clap's `trailing_var_arg`).
    pub fn trailingVarArg(self: Arg, yes: bool) Arg {
        var a = self;
        a.trailing_var_arg = yes;
        return a;
    }

    pub fn defaultMissingValue(self: Arg, v: []const u8) Arg {
        var a = self;
        a.default_missing_value = v;
        return a;
    }

    /// Conditional defaults, evaluated in order: the first condition that matches
    /// supplies this arg's default (or, with a null `value`, suppresses any
    /// default). Covers clap's `default_value_if(s)` / `default_values_if(s)`.
    pub fn defaultValueIfs(self: Arg, items: []const DefaultValueIf) Arg {
        var a = self;
        a.default_value_ifs = items;
        return a;
    }

    /// Restrict the accepted values to an enumerated set (clap's
    /// `value_parser([..])` / `PossibleValuesParser`).
    pub fn valueParser(self: Arg, values: []const []const u8) Arg {
        var a = self;
        a.possible_values = values;
        return a;
    }

    /// Validate values with a function (clap's `value_parser!(T)` / custom
    /// parsers), e.g. `clap.rangedInt(u16, 1, 65535)` or a user fn.
    pub fn valueParserFn(self: Arg, f: value_parser.ParserFn) Arg {
        var a = self;
        a.value_parser_fn = f;
        return a;
    }

    /// Enumerated values with per-value help (clap's `ValueEnum` / `PossibleValue`s).
    /// The help text is shown in long help (`--help`).
    pub fn possibleValues(self: Arg, values: []const PossibleValue) Arg {
        var a = self;
        a.value_help = values;
        return a;
    }

    /// The accepted value names (from `possibleValues` or `valueParser`), or null.
    pub fn possibleValueNames(self: Arg, allocator: std.mem.Allocator) ?[]const []const u8 {
        if (self.value_help) |vh| {
            var list: std.ArrayListUnmanaged([]const u8) = .empty;
            for (vh) |v| list.append(allocator, v.name) catch @panic("clap: OOM");
            return list.items;
        }
        return self.possible_values;
    }

    /// Add this argument to a named `ArgGroup`.
    pub fn group(self: Arg, id: []const u8) Arg {
        var a = self;
        a.group_id = id;
        return a;
    }

    /// Require that the named arg/group also be present when this one is.
    pub fn requires(self: Arg, id: []const u8) Arg {
        var a = self;
        a.requires_id = id;
        return a;
    }

    /// Require each `target` only when this arg holds the paired `value`
    /// (clap's `requires_if` / `requires_ifs`).
    pub fn requiresIfs(self: Arg, items: []const RequireIf) Arg {
        var a = self;
        a.requires_ifs = items;
        return a;
    }

    /// This arg is required unless ANY of the named args is present (clap's
    /// `required_unless_present` / `required_unless_present_any`).
    pub fn requiredUnlessPresentAny(self: Arg, ids: []const []const u8) Arg {
        var a = self;
        a.required_unless_any = ids;
        return a;
    }

    /// This arg is required unless ALL of the named args are present (clap's
    /// `required_unless_present_all`).
    pub fn requiredUnlessPresentAll(self: Arg, ids: []const []const u8) Arg {
        var a = self;
        a.required_unless_all = ids;
        return a;
    }

    /// This arg is required if ANY pair matches — i.e. some arg `target` holds
    /// the paired `value` (clap's `required_if_eq` / `required_if_eq_any`).
    pub fn requiredIfEqAny(self: Arg, items: []const RequireIf) Arg {
        var a = self;
        a.required_if_eq_any = items;
        return a;
    }

    /// This arg is required only if ALL pairs match — every arg `target` holds
    /// its paired `value` (clap's `required_if_eq_all`).
    pub fn requiredIfEqAll(self: Arg, items: []const RequireIf) Arg {
        var a = self;
        a.required_if_eq_all = items;
        return a;
    }

    /// This argument cannot be used together with any of the named ones
    /// (clap's `conflicts_with` / `conflicts_with_all`). Symmetric.
    pub fn conflictsWith(self: Arg, ids: []const []const u8) Arg {
        var a = self;
        a.conflicts_with = ids;
        return a;
    }

    /// Each named argument (and this one against itself, for self-override) is
    /// superseded by whichever of the overriding pair appears last on the command
    /// line (clap's `overrides_with` / `overrides_with_all`).
    pub fn overridesWith(self: Arg, ids: []const []const u8) Arg {
        var a = self;
        a.overrides = ids;
        return a;
    }

    /// Sort position within its help section (clap's `display_order`).
    pub fn displayOrder(self: Arg, n: usize) Arg {
        var a = self;
        a.disp_ord = n;
        return a;
    }

    /// Place this argument under a named help section, or the default `Options:`
    /// section when null (clap's `help_heading`). Overrides the command's
    /// `next_help_heading`.
    pub fn helpHeading(self: Arg, heading: ?[]const u8) Arg {
        var a = self;
        a.help_heading = heading;
        a.help_heading_set = true;
        return a;
    }

    /// Accept values that look like flags (`-x`, `--y`) for this arg (clap's
    /// `allow_hyphen_values`).
    pub fn allowHyphenValues(self: Arg, yes: bool) Arg {
        var a = self;
        a.allow_hyphen_values = yes;
        return a;
    }

    /// Accept negative-number values (`-20`, `-1.2`) for this arg, while other
    /// `-`-tokens are still flags (clap's `allow_negative_numbers`).
    pub fn allowNegativeNumbers(self: Arg, yes: bool) Arg {
        var a = self;
        a.allow_negative_numbers = yes;
        return a;
    }

    /// Whether a leading-`-` `token` should be taken as a value for this arg.
    pub fn acceptsHyphenValue(self: *const Arg, token: []const u8) bool {
        if (self.allow_hyphen_values) return true;
        return self.allow_negative_numbers and isNegativeNumber(token);
    }

    /// Omit this argument from help output and usage (clap's `hide`).
    pub fn hide(self: Arg, yes: bool) Arg {
        var a = self;
        a.is_hidden = yes;
        return a;
    }

    /// Hide this argument from the short (`-h`) help only (clap's `hide_short_help`).
    pub fn hideShortHelp(self: Arg, yes: bool) Arg {
        var a = self;
        a.hide_short_help = yes;
        return a;
    }

    /// Hide this argument from the long (`--help`) help only (clap's `hide_long_help`).
    pub fn hideLongHelp(self: Arg, yes: bool) Arg {
        var a = self;
        a.hide_long_help = yes;
        return a;
    }

    /// Whether this arg is shown in help for the given mode (clap's
    /// `should_show_arg`): never when fully hidden, else respecting the
    /// per-mode short/long hide flags.
    pub fn shownIn(self: *const Arg, for_long: bool) bool {
        if (self.is_hidden) return false;
        return if (for_long) !self.hide_long_help else !self.hide_short_help;
    }

    /// This argument conflicts with every other argument (clap's `exclusive`).
    pub fn exclusive(self: Arg, yes: bool) Arg {
        var a = self;
        a.is_exclusive = yes;
        return a;
    }

    /// Available to this command and all its subcommands; a match at any level
    /// is visible from every level (clap's `global`).
    pub fn global(self: Arg, yes: bool) Arg {
        var a = self;
        a.is_global = yes;
        return a;
    }

    /// Names for an option's values, shown in help; also fixes the value count
    /// to the number of names when `num_args` is unset (clap's `value_names`).
    pub fn valueNames(self: Arg, names: []const []const u8) Arg {
        var a = self;
        a.value_names = names;
        if (a.num_args == null) a.num_args = range.ValueRange.between(names.len, names.len);
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

    /// Whether help/usage shows a trailing `...` — i.e. the arg is repeatable or
    /// takes an unbounded number of values. A fixed multi-value arg (e.g. two
    /// value names) is NOT ellipsized (clap renders `<a> <b>`, no `...`).
    pub fn showsEllipsis(self: Arg) bool {
        return self.action_val == .append or self.action_val == .count or
            self.effectiveNumArgs().max == range.ValueRange.unbounded;
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

/// Whether `s` is a negative number (`-20`, `-1.2`) — for `allow_negative_numbers`.
pub fn isNegativeNumber(s: []const u8) bool {
    if (s.len < 2 or s[0] != '-') return false;
    _ = std.fmt.parseFloat(f64, s) catch return false;
    return true;
}

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
