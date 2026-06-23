const std = @import("std");
const command = @import("../builder/command.zig");
const arg = @import("../builder/arg.zig");
const lex = @import("../lex.zig");
const matcher = @import("matcher.zig");
const validator = @import("validator.zig");
const errors = @import("../error.zig");

const Command = command.Command;
const Arg = arg.Arg;
const ArgMatches = matcher.ArgMatches;
const Error = errors.Error;
const ValueSource = matcher.ValueSource;

/// External subcommands store their captured args under the empty id, matching
/// clap's `Id::EXTERNAL`.
pub const external_id = "";

/// Result of a parse: either matches or a clap error (which also carries
/// help/version display requests).
pub const Outcome = union(enum) {
    matches: *ArgMatches,
    err: Error,
};

const ParseState = union(enum) {
    values_done,
    /// awaiting the value of this option id
    opt: []const u8,
};

/// A flag-subcommand dispatch: invoke `name`, re-injecting any leftover short
/// cluster as `-<inject>` ahead of the remaining argv (clap's `-Sfp` chains).
const FlagSub = struct { name: []const u8, inject: ?[]const u8 };

/// Outcome of handling a single long/short token.
const FlagResult = union(enum) {
    values_done,
    opt: []const u8,
    /// help requested; payload is whether long (`--help`) vs short (`-h`)
    help: bool,
    version,
    flag_sub: FlagSub,
    err: Error,
};

const PosResult = union(enum) {
    cont,
    done,
    err: Error,
};

/// Parse `argv` (without the binary name) against `cmd`. Allocations come from
/// `allocator` (an arena in the blessed path) and panic on failure.
pub fn parse(allocator: std.mem.Allocator, cmd: *const Command, argv: []const []const u8) Outcome {
    const m = ArgMatches.create(allocator) catch @panic("clap: OOM matching");
    var p = Parser{
        .allocator = allocator,
        .cmd = cmd,
        .matches = m,
        .cursor = lex.Cursor.init(argv),
        .positional_count = cmd.countPositionals(),
        .contains_last = hasLast(cmd),
    };
    const outcome = p.loop();
    if (outcome == .matches) propagateGlobals(allocator, cmd, outcome.matches);
    return outcome;
}

/// Unify `global` args across the subcommand match chain: a global matched at
/// any level is copied into every level so it reads the same everywhere.
fn propagateGlobals(allocator: std.mem.Allocator, cmd: *const Command, root: *ArgMatches) void {
    var chain: std.ArrayListUnmanaged(*ArgMatches) = .empty;
    var node: ?*ArgMatches = root;
    while (node) |n| {
        chain.append(allocator, n) catch @panic("clap: OOM matching");
        node = if (n.sub) |s| s.matches else null;
    }
    if (chain.items.len < 2) return;
    for (cmd.arg_list.items) |*a| {
        if (!a.is_global) continue;
        var winner: ?*ArgMatches = null;
        for (chain.items) |n| {
            if (n.isPresent(a.id)) {
                winner = n;
                break;
            }
        }
        const w = winner orelse continue;
        for (chain.items) |n| {
            if (n != w) n.copyMatched(a.id, w);
        }
    }
}

/// Parse and then validate (clap's `try_get_matches_from`). Returns matches,
/// an error, or a help/version display request.
pub fn getMatches(allocator: std.mem.Allocator, cmd: *const Command, argv: []const []const u8) Outcome {
    switch (parse(allocator, cmd, argv)) {
        .err => |e| return .{ .err = e },
        .matches => |m| {
            if (validator.validate(allocator, cmd, m)) |e| return .{ .err = e };
            return .{ .matches = m };
        },
    }
}

fn hasLast(cmd: *const Command) bool {
    for (cmd.arg_list.items) |*a| {
        if (a.last_flag) return true;
    }
    return false;
}

const Parser = struct {
    allocator: std.mem.Allocator,
    cmd: *const Command,
    matches: *ArgMatches,
    cursor: lex.Cursor,
    positional_count: usize,
    contains_last: bool,

    state: ParseState = .values_done,
    pos_counter: usize = 1,
    trailing: bool = false,
    valid_arg_found: bool = false,
    /// clap's `cur_idx`: advanced once per flag-char slot and once per value slot.
    cur_idx: usize = 0,
    /// values collected so far for the pending option (`state == .opt`).
    pending_count: usize = 0,
    /// leftover short cluster to re-inject when dispatching a flag subcommand.
    flag_sub_inject: ?[]const u8 = null,

    fn loop(self: *Parser) Outcome {
        var subcmd_name: ?[]const u8 = null;
        while (self.cursor.next()) |token| {
            if (!self.trailing) {
                const parsed = lex.classify(token);
                // While collecting an option's values, a plain value continues it;
                // a flag/escape ends it (verify the count) before being handled.
                if (self.state == .opt) {
                    switch (parsed) {
                        .value, .stdio => {
                            self.consumeOptValue(token);
                            continue;
                        },
                        else => if (self.finalizePending()) |e| return .{ .err = e },
                    }
                }
                if (self.state == .values_done) {
                    switch (self.checkSubcommand(token)) {
                        .none => {},
                        .help => |target| return helpOutcome(target, true),
                        .matched => |name| {
                            subcmd_name = name;
                            break;
                        },
                        .err => |e| return .{ .err = e },
                    }
                }
                if (self.handleFlagsAndOptions(token, parsed)) |outcome| {
                    switch (outcome) {
                        .consumed => continue,
                        .ret => |o| return o,
                        .fall_through => {},
                        .flag_sub => |fs| {
                            subcmd_name = fs.name;
                            self.flag_sub_inject = fs.inject;
                            break;
                        },
                    }
                }
            }
            switch (self.handlePositional(token)) {
                .cont => continue,
                .done => return .{ .matches = self.matches },
                .err => |e| return .{ .err = e },
            }
        }
        if (self.finalizePending()) |e| return .{ .err = e };
        if (subcmd_name) |name| {
            if (self.parseSubcommand(name)) |e| return .{ .err = e };
        }
        self.applyDefaults();
        return .{ .matches = self.matches };
    }

    /// Append a value to the pending option, ending collection once `max` is reached.
    fn consumeOptValue(self: *Parser, token: []const u8) void {
        const a = self.cmd.findArgById(self.state.opt).?;
        self.pending_count += self.pushSplit(a, token);
        if (self.pending_count >= a.effectiveNumArgs().max) self.state = .values_done;
    }

    /// Finish a pending option, verifying it received at least `min` values.
    fn finalizePending(self: *Parser) ?Error {
        if (self.state != .opt) return null;
        const a = self.cmd.findArgById(self.state.opt).?;
        self.state = .values_done;
        const r = a.effectiveNumArgs();
        if (self.pending_count >= r.min) return null;
        return self.numValsError(a, r, self.pending_count);
    }

    // ----- token dispatch -----

    const FlagDispatch = union(enum) {
        consumed,
        ret: Outcome,
        fall_through,
        flag_sub: FlagSub,
    };

    fn handleFlagsAndOptions(self: *Parser, token: []const u8, parsed: lex.ParsedArg) ?FlagDispatch {
        _ = token;
        switch (parsed) {
            .escape => {
                self.trailing = true;
                return .consumed;
            },
            .long => |l| return self.applyFlagResult(self.parseLong(l)),
            .short => |s| return self.applyFlagResult(self.parseShort(s)),
            .stdio, .value => return .fall_through,
        }
    }

    fn applyFlagResult(self: *Parser, r: FlagResult) FlagDispatch {
        switch (r) {
            .values_done => {
                self.state = .values_done;
                return .consumed;
            },
            .opt => |id| {
                // start a fresh occurrence; values are gathered by consumeOptValue
                self.state = .{ .opt = id };
                self.pending_count = 0;
                if (self.cmd.findArgById(id)) |a| self.removeOverrides(a);
                self.matches.startOccurrence(id, .command_line);
                return .consumed;
            },
            .help => |long| return .{ .ret = helpOutcome(self.cmd, long) },
            .version => return .{ .ret = versionOutcome(self.cmd) },
            .flag_sub => |fs| return .{ .flag_sub = fs },
            .err => |e| return .{ .ret = .{ .err = e } },
        }
    }

    // ----- subcommands -----

    const SubCheck = union(enum) {
        none,
        help: *const Command,
        matched: []const u8,
        err: Error,
    };

    fn checkSubcommand(self: *Parser, token: []const u8) SubCheck {
        // the auto `help` subcommand only exists when there are real subcommands
        if (self.cmd.hasSubcommands() and !self.cmd.disable_help_subcommand and
            std.mem.eql(u8, token, "help") and self.cmd.findSubcommand("help") == null)
        {
            return self.helpSubcommandTarget();
        }
        if (self.cmd.findSubcommand(token)) |sc| return .{ .matched = sc.name };
        return .none;
    }

    fn helpSubcommandTarget(self: *Parser) SubCheck {
        var target = self.cmd;
        while (self.cursor.next()) |name| {
            if (target.findSubcommand(name)) |sc| {
                target = sc;
            } else {
                return .{ .err = self.mkErr(.invalid_subcommand, name, null) };
            }
        }
        return .{ .help = target };
    }

    fn parseSubcommand(self: *Parser, name: []const u8) ?Error {
        if (self.cmd.args_conflicts_with_subcommands and self.valid_arg_found) {
            return self.mkErr(.argument_conflict, name, null);
        }
        const sc = self.cmd.findSubcommand(name).?;
        const child = ArgMatches.create(self.allocator) catch @panic("clap: OOM matching");
        // flag-subcommand dispatch re-injects the leftover short cluster as `-rest`
        var child_cursor = lex.Cursor{ .args = self.cursor.args, .index = self.cursor.index };
        if (self.flag_sub_inject) |rest| {
            if (rest.len > 0) {
                var list: std.ArrayListUnmanaged([]const u8) = .empty;
                list.append(self.allocator, std.fmt.allocPrint(self.allocator, "-{s}", .{rest}) catch @panic("clap: OOM")) catch @panic("clap: OOM");
                list.appendSlice(self.allocator, self.cursor.remaining()) catch @panic("clap: OOM");
                child_cursor = lex.Cursor.init(list.items);
            }
        }
        var child_parser = Parser{
            .allocator = self.allocator,
            .cmd = sc,
            .matches = child,
            .cursor = child_cursor,
            .positional_count = sc.countPositionals(),
            .contains_last = hasLast(sc),
        };
        switch (child_parser.loop()) {
            .matches => |cm| self.matches.setSubcommand(sc.name, cm),
            .err => |e| return e,
        }
        return null;
    }

    // ----- long / short -----

    /// A help/version action on a matched arg yields the corresponding outcome
    /// (clap's `ArgAction::Help`/`HelpShort`/`HelpLong`/`Version`).
    fn actionResult(action_val: @import("../builder/action.zig").ArgAction) ?FlagResult {
        return switch (action_val) {
            .help, .help_long => .{ .help = true },
            .help_short => .{ .help = false },
            .version => .version,
            else => null,
        };
    }

    fn parseLong(self: *Parser, l: lex.Long) FlagResult {
        if (!self.cmd.disable_help_flag and std.mem.eql(u8, l.name, "help") and
            self.cmd.findArgByLong("help") == null)
        {
            return .{ .help = true };
        }
        if (self.cmd.hasVersionFlag() and std.mem.eql(u8, l.name, "version") and
            self.cmd.findArgByLong("version") == null)
        {
            return .version;
        }
        const a = self.cmd.findArgByLong(l.name) orelse {
            if (self.cmd.findFlagSubcommandLong(l.name)) |sc| return .{ .flag_sub = .{ .name = sc.name, .inject = null } };
            return .{ .err = self.mkErr(.unknown_argument, self.dashed(l.name), null) };
        };
        self.valid_arg_found = true;
        if (actionResult(a.action_val)) |r| return r;
        if (self.reuseError(a)) |e| return .{ .err = e };
        if (!a.takesValue()) {
            if (l.value != null) {
                const used = self.allocator.dupe([]const u8, &.{a.id}) catch @panic("clap: OOM");
                return .{ .err = .{ .kind = .too_many_values, .cmd = self.cmd, .arg = self.dashed(l.name), .value = l.value, .used_ids = used } };
            }
            self.recordArg(a, &.{}, .command_line);
            return .values_done;
        }
        return self.parseOptValue(a, l.value, l.value != null);
    }

    fn parseShort(self: *Parser, cluster: []const u8) FlagResult {
        var rest = cluster;
        while (rest.len > 0) {
            const c = rest[0];
            rest = rest[1..];
            if (!self.cmd.disable_help_flag and c == 'h' and self.cmd.findArgByShort('h') == null) {
                return .{ .help = false };
            }
            if (self.cmd.hasVersionFlag() and c == 'V' and self.cmd.findArgByShort('V') == null) {
                return .version;
            }
            const a = self.cmd.findArgByShort(c) orelse {
                if (self.cmd.findFlagSubcommandShort(c)) |sc| return .{ .flag_sub = .{ .name = sc.name, .inject = rest } };
                return .{ .err = self.mkErr(.unknown_argument, self.shortDisplay(c), null) };
            };
            self.valid_arg_found = true;
            if (actionResult(a.action_val)) |r| return r;
            if (self.reuseError(a)) |e| return .{ .err = e };
            if (!a.takesValue()) {
                self.recordArg(a, &.{}, .command_line);
                continue;
            }
            if (rest.len > 0) {
                const has_eq = rest[0] == '=';
                const val = if (has_eq) rest[1..] else rest;
                return self.parseOptValue(a, val, has_eq);
            }
            return self.parseOptValue(a, null, false);
        }
        return .values_done;
    }

    fn parseOptValue(self: *Parser, a: *const Arg, attached: ?[]const u8, has_eq: bool) FlagResult {
        self.cur_idx += 1; // the option's own flag slot (clap records the value index next)
        if (a.require_equals and !has_eq) {
            if (a.effectiveNumArgs().min == 0) {
                self.recordArg(a, &.{}, .command_line);
                return .values_done;
            }
            return .{ .err = self.mkErr(.no_equals, self.eqDisplay(a), null) };
        }
        if (attached) |v| {
            self.recordArg(a, &.{v}, .command_line);
            return .values_done;
        }
        return .{ .opt = a.id };
    }

    // ----- positionals / external -----

    fn handlePositional(self: *Parser, token: []const u8) PosResult {
        if (self.trailing and self.contains_last) self.pos_counter = self.positional_count;
        if (self.cmd.getPositional(self.pos_counter)) |a| {
            if (a.last_flag and !self.trailing) {
                return .{ .err = self.mkErr(.unknown_argument, token, null) };
            }
            self.recordArg(a, &.{token}, .command_line);
            self.valid_arg_found = true;
            if (!a.isMultiple()) self.pos_counter += 1;
            return .cont;
        }
        if (self.cmd.allow_external_subcommands) return self.captureExternal(token);
        return .{ .err = self.mkErr(.unknown_argument, token, null) };
    }

    fn captureExternal(self: *Parser, name: []const u8) PosResult {
        const child = ArgMatches.create(self.allocator) catch @panic("clap: OOM matching");
        child.startOccurrence(external_id, .command_line);
        while (self.cursor.next()) |t| {
            self.cur_idx += 1;
            child.pushValue(external_id, t, self.cur_idx);
        }
        self.matches.setSubcommand(name, child);
        return .done;
    }

    // ----- recording / defaults -----

    fn recordArg(self: *Parser, a: *const Arg, vals: []const []const u8, source: ValueSource) void {
        if (source == .command_line) self.removeOverrides(a);
        self.matches.startOccurrence(a.id, source);
        if (vals.len == 0) {
            if (a.default_missing_value) |dm| {
                self.pushVal(a.id, dm);
            } else if (a.action_val == .set_true) {
                self.pushVal(a.id, "true");
            } else if (a.action_val == .set_false) {
                self.pushVal(a.id, "false");
            } else if (a.action_val == .count) {
                // Count keeps only the latest index (value unused; getCount reads occurrences)
                self.matches.clearValues(a.id);
                self.pushVal(a.id, "");
            }
            return;
        }
        for (vals) |v| _ = self.pushSplit(a, v);
    }

    /// Record a raw value, splitting it on the arg's `value_delimiter` into
    /// separate values when one is set. Returns how many values were recorded.
    fn pushSplit(self: *Parser, a: *const Arg, token: []const u8) usize {
        if (a.value_delimiter) |d| {
            var it = std.mem.splitScalar(u8, token, d);
            var n: usize = 0;
            while (it.next()) |piece| {
                self.pushVal(a.id, piece);
                n += 1;
            }
            return n;
        }
        self.pushVal(a.id, token);
        return 1;
    }

    /// On a new explicit occurrence, drop any args this one overrides, plus any
    /// already-matched arg that overrides this one (so the later of an override
    /// pair wins). Port of clap's `Parser::remove_overrides`.
    fn removeOverrides(self: *Parser, a: *const Arg) void {
        if (a.overrides) |ov| {
            for (ov) |oid| self.matches.remove(oid);
        }
        for (self.cmd.arg_list.items) |*b| {
            if (!self.matches.contains(b.id)) continue;
            const bov = b.overrides orelse continue;
            if (idIn(bov, a.id)) self.matches.remove(b.id);
        }
    }

    /// Advance the parse-index and record one value at the new slot.
    fn pushVal(self: *Parser, id: []const u8, val: []const u8) void {
        self.cur_idx += 1;
        self.matches.pushValue(id, val, self.cur_idx);
    }

    fn applyDefaults(self: *Parser) void {
        for (self.cmd.arg_list.items) |*a| self.applyArgDefault(a);
    }

    /// Conditional defaults take precedence over the regular default: the first
    /// matching `default_value_if` wins and supplies (or, with no value,
    /// suppresses) the default. Port of clap's `add_default_value`.
    fn applyArgDefault(self: *Parser, a: *const Arg) void {
        if (a.default_value_ifs) |conds| {
            if (!self.matches.contains(a.id)) {
                for (conds) |c| {
                    if (!self.conditionHolds(c)) continue;
                    if (c.value) |vals| {
                        const first = self.cur_idx + 1;
                        self.cur_idx += vals.len;
                        self.matches.setDefaults(a.id, vals, first);
                    }
                    return; // first match wins; skip the regular default
                }
            }
        }
        if (a.default_value) |dv| {
            if (a.value_delimiter) |d| {
                self.setDefaultSplit(a.id, dv, d);
            } else {
                self.cur_idx += 1;
                self.matches.setDefault(a.id, dv, self.cur_idx);
            }
            return;
        }
        const imp = implicitDefault(a.action_val) orelse return;
        self.cur_idx += 1;
        self.matches.setDefault(a.id, imp, self.cur_idx);
    }

    /// Seed a default value split on the arg's delimiter into multiple values.
    fn setDefaultSplit(self: *Parser, id: []const u8, value: []const u8, d: u8) void {
        var pieces: std.ArrayListUnmanaged([]const u8) = .empty;
        var it = std.mem.splitScalar(u8, value, d);
        while (it.next()) |piece| pieces.append(self.allocator, piece) catch @panic("clap: OOM");
        const first = self.cur_idx + 1;
        self.cur_idx += pieces.items.len;
        self.matches.setDefaults(id, pieces.items, first);
    }

    /// Whether a conditional-default predicate holds: the referenced arg is
    /// present (when `equals` is null) or holds the given value.
    fn conditionHolds(self: *Parser, c: @import("../builder/arg.zig").DefaultValueIf) bool {
        if (c.equals) |v| {
            const vals = self.matches.getRaw(c.arg) orelse return false;
            for (vals) |x| {
                if (std.mem.eql(u8, x, v)) return true;
            }
            return false;
        }
        return self.matches.contains(c.arg);
    }

    /// SetTrue/SetFalse/Count carry an implicit default, so they are always present
    /// (contains-true) with a value even when absent — matching clap.
    fn implicitDefault(action_val: @import("../builder/action.zig").ArgAction) ?[]const u8 {
        return switch (action_val) {
            .set_true => "false",
            .set_false => "true",
            .count => "0",
            else => null,
        };
    }

    // ----- error helpers -----

    fn mkErr(self: *Parser, kind: errors.ErrorKind, name: ?[]const u8, value: ?[]const u8) Error {
        return .{ .kind = kind, .cmd = self.cmd, .arg = name, .value = value };
    }

    /// A non-multiple flag/option used a second time: error, unless
    /// `args_override_self` is set, in which case the prior occurrence is cleared.
    fn reuseError(self: *Parser, a: *const Arg) ?Error {
        if (a.isMultiple() or !self.matches.isPresent(a.id)) return null;
        // A self-overriding arg supersedes its prior occurrence (cleared by
        // `removeOverrides` on record), so it never errors on repeat.
        if (selfOverrides(a)) return null;
        if (self.cmd.args_override_self) {
            self.matches.reset(a.id);
            return null;
        }
        const disp = if (a.long_name) |l| self.dashed(l) else self.shortDisplay(a.short_char.?);
        return .{ .kind = .argument_conflict, .cmd = self.cmd, .arg = disp, .multiple_use = true };
    }

    fn dashed(self: *Parser, name: []const u8) []const u8 {
        return std.fmt.allocPrint(self.allocator, "--{s}", .{name}) catch @panic("clap: OOM");
    }

    fn shortDisplay(self: *Parser, c: u8) []const u8 {
        return std.fmt.allocPrint(self.allocator, "-{c}", .{c}) catch @panic("clap: OOM");
    }

    fn argDisplay(self: *Parser, a: *const Arg) []const u8 {
        if (a.long_name) |l| return self.dashed(l);
        if (a.short_char) |c| return self.shortDisplay(c);
        return a.id;
    }

    /// Whether `a` lists its own id in `overrides_with` (clap's self-override:
    /// repeating it replaces the prior occurrence rather than erroring).
    fn selfOverrides(a: *const Arg) bool {
        const ov = a.overrides orelse return false;
        return idIn(ov, a.id);
    }

    fn idIn(ids: []const []const u8, needle: []const u8) bool {
        for (ids) |id| {
            if (std.mem.eql(u8, id, needle)) return true;
        }
        return false;
    }

    /// Build the wrong/too-few/required-value error for a pending option that
    /// got `count` values when its range required more.
    fn numValsError(self: *Parser, a: *const Arg, r: @import("../builder/range.zig").ValueRange, count: usize) Error {
        if (count == 0) {
            return .{ .kind = .invalid_value, .cmd = self.cmd, .arg = self.multiValDisplay(a, 1, r.max > 1), .value_required = true };
        }
        if (r.min == r.max) {
            return .{ .kind = .wrong_number_of_values, .cmd = self.cmd, .arg = self.multiValDisplay(a, r.min, false), .n_expected = r.min, .n_provided = count };
        }
        return .{ .kind = .too_few_values, .cmd = self.cmd, .arg = self.multiValDisplay(a, r.min, true), .n_expected = r.min, .n_provided = count };
    }

    /// e.g. `-o <option> <option> <option>` (repeats) with an optional trailing `...`.
    fn multiValDisplay(self: *Parser, a: *const Arg, repeats: usize, ellipsis: bool) []const u8 {
        var b: std.ArrayListUnmanaged(u8) = .empty;
        b.appendSlice(self.allocator, self.argDisplay(a)) catch @panic("clap: OOM");
        const name = a.value_name orelse a.id;
        var i: usize = 0;
        while (i < repeats) : (i += 1) {
            b.appendSlice(self.allocator, " <") catch @panic("clap: OOM");
            b.appendSlice(self.allocator, name) catch @panic("clap: OOM");
            b.appendSlice(self.allocator, ">") catch @panic("clap: OOM");
        }
        if (ellipsis) b.appendSlice(self.allocator, "...") catch @panic("clap: OOM");
        return b.items;
    }

    /// Display for a require_equals option in a no-equals error: `--config=<cfg>`.
    fn eqDisplay(self: *Parser, a: *const Arg) []const u8 {
        const flag = self.argDisplay(a);
        return std.fmt.allocPrint(self.allocator, "{s}=<{s}>", .{ flag, a.value_name orelse a.id }) catch
            @panic("clap: OOM");
    }
};

fn helpOutcome(cmd: *const Command, long: bool) Outcome {
    return .{ .err = .{ .kind = .display_help, .cmd = cmd, .help_long = long } };
}

fn versionOutcome(cmd: *const Command) Outcome {
    return .{ .err = .{ .kind = .display_version, .cmd = cmd } };
}
