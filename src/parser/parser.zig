const std = @import("std");
const command = @import("../builder/command.zig");
const arg = @import("../builder/arg.zig");
const lex = @import("../lex.zig");
const matcher = @import("matcher.zig");
const validator = @import("validator.zig");
const errors = @import("../error.zig");
const env = @import("../env.zig");
const suggest = @import("../suggest.zig");
const range = @import("../builder/range.zig");
const layout = @import("../output/layout.zig");

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
    /// version requested; payload is whether long (`--version`) vs short (`-V`)
    version: bool,
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
    return parseEnv(allocator, cmd, argv, null);
}

/// Like `parse`, but `env_source` supplies values for `Arg.env` fallbacks.
pub fn parseEnv(allocator: std.mem.Allocator, cmd: *const Command, argv: []const []const u8, env_source: ?env.EnvSource) Outcome {
    const m = ArgMatches.create(allocator) catch @panic("clap: OOM matching");
    var p = Parser{
        .allocator = allocator,
        .cmd = cmd,
        .matches = m,
        .cursor = lex.Cursor.init(argv),
        .positional_count = cmd.countPositionals(),
        .contains_last = hasLast(cmd),
        .env_source = env_source,
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
    return getMatchesEnv(allocator, cmd, argv, null);
}

/// Like `getMatches`, but `env_source` supplies values for `Arg.env` fallbacks.
pub fn getMatchesEnv(allocator: std.mem.Allocator, cmd: *const Command, argv: []const []const u8, env_source: ?env.EnvSource) Outcome {
    switch (parseEnv(allocator, cmd, argv, env_source)) {
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
    /// id whose occurrence group is currently open for appending values; a new
    /// group begins on each option occurrence or a non-contiguous positional run
    open_group: ?[]const u8 = null,
    /// caller-supplied env lookup for `Arg.env` fallbacks (null = no env).
    env_source: ?env.EnvSource = null,

    /// Under `ignore_errors`, recoverable errors are swallowed so parsing
    /// continues with best-effort matches; help/version display still propagates.
    fn ignorable(self: *Parser, e: Error) bool {
        if (!self.cmd.ignore_errors) return false;
        return switch (e.kind) {
            .display_help, .display_version, .display_help_on_missing_argument_or_subcommand => false,
            else => true,
        };
    }

    fn loop(self: *Parser) Outcome {
        var subcmd_name: ?[]const u8 = null;
        while (self.cursor.next()) |token| {
            if (!self.trailing) {
                const parsed = lex.classify(token);
                // While collecting an option's values, a plain value continues it;
                // a flag/escape ends it (verify the count) before being handled.
                if (self.state == .opt) {
                    // a value_terminator ends collection and is itself consumed
                    // (takes precedence over allow_hyphen_values)
                    const pending = self.cmd.findArgById(self.state.opt).?;
                    if (pending.value_terminator) |term| {
                        if (std.mem.eql(u8, token, term)) {
                            if (self.finalizePending()) |e| if (!self.ignorable(e)) return .{ .err = e };
                            continue;
                        }
                    }
                    switch (parsed) {
                        .value, .stdio => {
                            self.consumeOptValue(token);
                            continue;
                        },
                        // a flag-looking token ends the option — unless the option
                        // accepts hyphen values, in which case it's another value
                        else => {
                            const opt = self.cmd.findArgById(self.state.opt).?;
                            if (opt.acceptsHyphenValue(token)) {
                                self.consumeOptValue(token);
                                continue;
                            }
                            if (self.finalizePending()) |e| if (!self.ignorable(e)) return .{ .err = e };
                        },
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
                        .err => |e| {
                            if (self.ignorable(e)) continue;
                            return .{ .err = e };
                        },
                    }
                }
                // a leading-`-` token goes to the next positional when that
                // positional accepts hyphen values (clap's allow_hyphen_values /
                // allow_negative_numbers), bypassing flag parsing
                if (!self.hyphenPositional(token, parsed)) {
                    if (self.handleFlagsAndOptions(token, parsed)) |outcome| {
                        switch (outcome) {
                            .consumed => continue,
                            .ret => |o| {
                                if (o == .err and self.ignorable(o.err)) continue;
                                return o;
                            },
                            .fall_through => {},
                            .flag_sub => |fs| {
                                subcmd_name = fs.name;
                                self.flag_sub_inject = fs.inject;
                                break;
                            },
                        }
                    }
                }
            }
            switch (self.handlePositional(token)) {
                .cont => continue,
                .done => return .{ .matches = self.matches },
                .err => |e| {
                    if (self.ignorable(e)) continue;
                    return .{ .err = e };
                },
            }
        }
        if (self.finalizePending()) |e| if (!self.ignorable(e)) return .{ .err = e };
        if (subcmd_name) |name| {
            if (self.parseSubcommand(name)) |e| if (!self.ignorable(e)) return .{ .err = e };
        }
        self.applyEnv();
        self.applyDefaults();
        self.recordGroups();
        return .{ .matches = self.matches };
    }

    /// Record each group's present members under the group id so a group can be
    /// queried like an arg (clap's `get_one`/`get_many`/`contains_id` on a group).
    fn recordGroups(self: *Parser) void {
        for (self.cmd.groups.items) |*g| self.recordGroup(g.id);
        for (self.cmd.arg_list.items) |*a| {
            if (a.group_id) |gid| self.recordGroup(gid);
        }
    }

    fn recordGroup(self: *Parser, gid: []const u8) void {
        var members: std.ArrayListUnmanaged([]const u8) = .empty;
        for (self.cmd.arg_list.items) |*a| {
            if (self.cmd.argInGroupId(a, gid) and self.matches.isPresent(a.id)) {
                members.append(self.allocator, a.id) catch @panic("clap: OOM");
            }
        }
        if (members.items.len > 0) self.matches.setGroupMembers(gid, members.items);
    }

    /// Env fallback (clap's `Arg.env`): for each absent env-bound arg, take the
    /// value from the env source, splitting on the delimiter like a CLI value.
    /// Runs before defaults, so precedence is CLI > env > default.
    fn applyEnv(self: *Parser) void {
        const src = self.env_source orelse return;
        for (self.cmd.arg_list.items) |*a| {
            const name = a.env_var orelse continue;
            if (self.matches.contains(a.id)) continue;
            const raw = src.get(name) orelse continue;
            var vals: std.ArrayListUnmanaged([]const u8) = .empty;
            if (a.value_delimiter) |d| {
                var it = std.mem.splitScalar(u8, raw, d);
                while (it.next()) |piece| vals.append(self.allocator, piece) catch @panic("clap: OOM");
            } else {
                vals.append(self.allocator, raw) catch @panic("clap: OOM");
            }
            const first = self.cur_idx + 1;
            self.cur_idx += vals.items.len;
            self.matches.setEnv(a.id, vals.items, first);
        }
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

    /// Whether a leading-`-` `token` should fill the next positional instead of
    /// being parsed as a flag (the positional has allow_hyphen_values / accepts
    /// this negative number). Excludes the `--` escape and lone `-`.
    fn hyphenPositional(self: *Parser, token: []const u8, parsed: lex.ParsedArg) bool {
        if (self.state != .values_done) return false;
        if (token.len < 2 or token[0] != '-') return false;
        if (std.mem.eql(u8, token, "--")) return false;
        if (self.isRecognizedFlag(parsed)) return false; // defined flags still win
        const p = self.cmd.getPositional(self.pos_counter) orelse return false;
        return p.acceptsHyphenValue(token);
    }

    /// Whether `parsed` names a defined option/flag (incl. the auto help/version
    /// flags and flag subcommands) — such tokens are never hyphen-value fodder.
    fn isRecognizedFlag(self: *Parser, parsed: lex.ParsedArg) bool {
        switch (parsed) {
            .long => |l| {
                if (self.cmd.findArgByLong(l.name) != null) return true;
                if (!self.cmd.disable_help_flag and std.mem.eql(u8, l.name, "help")) return true;
                if (self.cmd.hasVersionFlag() and std.mem.eql(u8, l.name, "version")) return true;
                return self.cmd.findFlagSubcommandLong(l.name) != null;
            },
            .short => |s| {
                const c = s[0];
                if (self.cmd.findArgByShort(c) != null) return true;
                if (!self.cmd.disable_help_flag and c == 'h') return true;
                if (self.cmd.hasVersionFlag() and c == 'V') return true;
                return self.cmd.findFlagSubcommandShort(c) != null;
            },
            else => return false,
        }
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
                self.matches.beginGroup(id);
                self.open_group = id;
                return .consumed;
            },
            .help => |long| return .{ .ret = helpOutcome(self.cmd, long) },
            .version => |long| return .{ .ret = versionOutcome(self.cmd, long) },
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
        if (!self.cmd.hasSubcommands() or std.mem.startsWith(u8, token, "-")) return .none;
        if (self.cmd.infer_subcommands) switch (self.cmd.inferSubcommand(token)) {
            .unique => |sc| return .{ .matched = sc.name },
            .ambiguous, .none => {},
        };
        // not a subcommand: a free positional slot (or an external-subcommand
        // catch-all) still consumes the token as a value
        if (self.cmd.getPositional(self.pos_counter) != null) return .none;
        if (self.cmd.allow_external_subcommands) return .none;
        // a bare token that can't be placed is a failed subcommand (clap's
        // match_arg_error): suggest similar names, else error only when the
        // command takes no positionals at all (or infers subcommands)
        var e = self.mkErr(.invalid_subcommand, token, null);
        if (self.subcommandSuggestions(token)) |s| {
            e.suggestions = s;
            return .{ .err = e };
        }
        if (self.cmd.countPositionals() == 0 or self.cmd.infer_subcommands) {
            return .{ .err = e };
        }
        return .none;
    }

    fn subcommandSuggestions(self: *Parser, token: []const u8) ?[]const []const u8 {
        var names: std.ArrayListUnmanaged([]const u8) = .empty;
        for (self.cmd.subcommands.items) |*sc| {
            names.append(self.allocator, sc.name) catch @panic("clap: OOM");
            if (sc.aliases_list) |al| for (al) |x| names.append(self.allocator, x) catch @panic("clap: OOM");
        }
        const cands = suggest.didYouMean(self.allocator, token, names.items);
        return if (cands.len == 0) null else cands;
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
            .env_source = self.env_source,
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
    fn actionResult(action_val: @import("../builder/action.zig").ArgAction, long: bool) ?FlagResult {
        return switch (action_val) {
            .help, .help_long => .{ .help = true },
            .help_short => .{ .help = false },
            .version => .{ .version = long },
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
            return .{ .version = true };
        }
        const a = self.cmd.findArgByLong(l.name) orelse blk: {
            if (self.cmd.findFlagSubcommandLong(l.name)) |sc| return .{ .flag_sub = .{ .name = sc.name, .inject = null } };
            if (self.cmd.infer_long_args) switch (self.cmd.inferArgByLong(l.name)) {
                .unique => |ia| break :blk ia,
                .ambiguous => return .{ .err = self.mkErr(.unknown_argument, self.dashed(l.name), null) },
                .none => {},
            };
            if (self.cmd.infer_subcommands) switch (self.cmd.inferFlagSubcommandLong(l.name)) {
                .unique => |sc| return .{ .flag_sub = .{ .name = sc.name, .inject = null } },
                .ambiguous => return .{ .err = self.mkErr(.unknown_argument, self.dashed(l.name), null) },
                .none => {},
            };
            return .{ .err = self.unknownLongError(l.name) };
        };
        self.valid_arg_found = true;
        if (actionResult(a.action_val, true)) |r| return r;
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
                return .{ .version = false };
            }
            const a = self.cmd.findArgByShort(c) orelse {
                if (self.cmd.findFlagSubcommandShort(c)) |sc| return .{ .flag_sub = .{ .name = sc.name, .inject = rest } };
                return .{ .err = self.mkErr(.unknown_argument, self.shortDisplay(c), null) };
            };
            self.valid_arg_found = true;
            if (actionResult(a.action_val, false)) |r| return r;
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
            // a value_terminator ends this positional and is consumed; later
            // tokens fall to the next positional slot
            if (a.value_terminator) |term| {
                if (std.mem.eql(u8, token, term)) {
                    self.pos_counter += 1;
                    return .cont;
                }
            }
            // a bounded-range positional (e.g. `1..=3`) rejects the value past its
            // max; a fixed-count one (`3`) over-fills and is caught post-parse so
            // the error reports the total count (clap's two distinct behaviors)
            const r = a.effectiveNumArgs();
            if (a.isMultiple() and r.max != range.ValueRange.unbounded and r.min != r.max) {
                const have = if (self.matches.getRaw(a.id)) |v| v.len else 0;
                if (have >= r.max) {
                    return .{ .err = .{ .kind = .too_many_values, .cmd = self.cmd, .arg = layout.positionalNotationStr(self.allocator, a), .value = token } };
                }
            }
            self.recordArg(a, &.{token}, .command_line);
            self.valid_arg_found = true;
            // a trailing-var-arg positional swallows everything after its first
            // value (flags, `--`, hyphen values) as literal values
            if (a.trailing_var_arg) self.trailing = true;
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
        if (source == .command_line) self.openGroup(a);
        if (vals.len == 0) {
            if (a.default_missing_value) |dm| {
                self.pushVal(a.id, dm);
            } else if (a.action_val == .set_true) {
                self.pushVal(a.id, "true");
            } else if (a.action_val == .set_false) {
                self.pushVal(a.id, "false");
            } else if (a.action_val == .count) {
                // Count stores the running total as its value (clap: the count IS
                // the value, so getOne/default_value_if read it); occurrences track
                // it too. Keep only the latest value/index.
                self.matches.clearValues(a.id);
                const n = self.matches.getCount(a.id);
                self.pushVal(a.id, std.fmt.allocPrint(self.allocator, "{d}", .{n}) catch @panic("clap: OOM"));
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
    /// Begin a new occurrence group: always for options/flags (each appearance is
    /// an occurrence), but for a positional only when its run isn't contiguous with
    /// the previous value (clap groups contiguous positional values together).
    fn openGroup(self: *Parser, a: *const Arg) void {
        if (a.isPositional()) {
            if (self.open_group != null and std.mem.eql(u8, self.open_group.?, a.id)) return;
        }
        self.matches.beginGroup(a.id);
        self.open_group = a.id;
    }

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

    /// `unknown_argument` for an unmatched `--long`, carrying a "did you mean"
    /// suggestion of the most similar defined long flag (clap's did_you_mean_flag).
    /// The suggested arg is recorded as present so the usage line names it
    /// instead of `[OPTIONS]` (clap's `start_custom_arg`).
    fn unknownLongError(self: *Parser, name: []const u8) Error {
        var e = self.mkErr(.unknown_argument, self.dashed(name), null);
        const cand = self.bestLong(name) orelse return e;
        e.suggestions = self.allocator.dupe([]const u8, &.{self.dashed(cand)}) catch @panic("clap: OOM");
        // under ignore_errors the error is dropped, so don't record the suggested
        // arg (clap skips start_custom_arg) — it should keep its default source
        if (self.cmd.ignore_errors) return e;
        if (self.cmd.findArgByLong(cand)) |a| {
            self.matches.startOccurrence(a.id, .command_line);
            e.used_ids = self.matches.presentIds(self.allocator);
        }
        return e;
    }

    fn bestLong(self: *Parser, name: []const u8) ?[]const u8 {
        var longs: std.ArrayListUnmanaged([]const u8) = .empty;
        for (self.cmd.arg_list.items) |*a| {
            if (a.long_name) |l| longs.append(self.allocator, l) catch @panic("clap: OOM");
            if (a.aliases_list) |al| for (al) |x| longs.append(self.allocator, x) catch @panic("clap: OOM");
        }
        if (!self.cmd.disable_help_flag) longs.append(self.allocator, "help") catch @panic("clap: OOM");
        if (self.cmd.hasVersionFlag()) longs.append(self.allocator, "version") catch @panic("clap: OOM");
        const cands = suggest.didYouMean(self.allocator, name, longs.items);
        if (cands.len == 0) return null;
        return cands[cands.len - 1];
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

fn versionOutcome(cmd: *const Command, long: bool) Outcome {
    return .{ .err = .{ .kind = .display_version, .cmd = cmd, .version_long = long } };
}
