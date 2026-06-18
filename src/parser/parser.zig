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

/// Outcome of handling a single long/short token.
const FlagResult = union(enum) {
    values_done,
    opt: []const u8,
    /// help requested; payload is whether long (`--help`) vs short (`-h`)
    help: bool,
    version,
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
    return p.loop();
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

    fn loop(self: *Parser) Outcome {
        var subcmd_name: ?[]const u8 = null;
        while (self.cursor.next()) |token| {
            if (!self.trailing) {
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
                if (self.handleFlagsAndOptions(token)) |outcome| {
                    switch (outcome) {
                        .consumed => continue,
                        .ret => |o| return o,
                        .fall_through => {},
                    }
                }
            }
            switch (self.handlePositional(token)) {
                .cont => continue,
                .done => return .{ .matches = self.matches },
                .err => |e| return .{ .err = e },
            }
        }
        if (subcmd_name) |name| {
            if (self.parseSubcommand(name)) |e| return .{ .err = e };
        }
        self.applyDefaults();
        return .{ .matches = self.matches };
    }

    // ----- token dispatch -----

    const FlagDispatch = union(enum) {
        consumed,
        ret: Outcome,
        fall_through,
    };

    fn handleFlagsAndOptions(self: *Parser, token: []const u8) ?FlagDispatch {
        switch (lex.classify(token)) {
            .escape => {
                self.trailing = true;
                return .consumed;
            },
            .long => |l| return self.applyFlagResult(self.parseLong(l)),
            .short => |s| return self.applyFlagResult(self.parseShort(s)),
            .stdio, .value => {},
        }
        if (self.state == .opt) {
            const id = self.state.opt;
            const a = self.cmd.findArgById(id).?;
            self.recordArg(a, &.{token}, .command_line);
            self.state = .values_done;
            return .consumed;
        }
        return .fall_through;
    }

    fn applyFlagResult(self: *Parser, r: FlagResult) FlagDispatch {
        switch (r) {
            .values_done => {
                self.state = .values_done;
                return .consumed;
            },
            .opt => |id| {
                self.state = .{ .opt = id };
                return .consumed;
            },
            .help => |long| return .{ .ret = helpOutcome(self.cmd, long) },
            .version => return .{ .ret = versionOutcome(self.cmd) },
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
        if (!self.cmd.disable_help_subcommand and std.mem.eql(u8, token, "help") and
            self.cmd.findSubcommand("help") == null)
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
        var child_parser = Parser{
            .allocator = self.allocator,
            .cmd = sc,
            .matches = child,
            .cursor = .{ .args = self.cursor.args, .index = self.cursor.index },
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
        const a = self.cmd.findArgByLong(l.name) orelse
            return .{ .err = self.mkErr(.unknown_argument, self.dashed(l.name), null) };
        self.valid_arg_found = true;
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
            const a = self.cmd.findArgByShort(c) orelse
                return .{ .err = self.mkErr(.unknown_argument, self.shortDisplay(c), null) };
            self.valid_arg_found = true;
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
        while (self.cursor.next()) |t| child.pushValue(external_id, t);
        self.matches.setSubcommand(name, child);
        return .done;
    }

    // ----- recording / defaults -----

    fn recordArg(self: *Parser, a: *const Arg, vals: []const []const u8, source: ValueSource) void {
        self.matches.startOccurrence(a.id, source);
        if (vals.len == 0) {
            if (a.default_missing_value) |dm| {
                self.matches.pushValue(a.id, dm);
            } else if (a.action_val == .set_true) {
                self.matches.pushValue(a.id, "true");
            } else if (a.action_val == .set_false) {
                self.matches.pushValue(a.id, "false");
            }
            return;
        }
        for (vals) |v| self.matches.pushValue(a.id, v);
    }

    fn applyDefaults(self: *Parser) void {
        for (self.cmd.arg_list.items) |*a| {
            if (a.default_value) |dv| self.matches.setDefault(a.id, dv);
        }
    }

    // ----- error helpers -----

    fn mkErr(self: *Parser, kind: errors.ErrorKind, name: ?[]const u8, value: ?[]const u8) Error {
        return .{ .kind = kind, .cmd = self.cmd, .arg = name, .value = value };
    }

    /// A non-multiple flag/option used a second time on the command line is an error.
    fn reuseError(self: *Parser, a: *const Arg) ?Error {
        if (a.isMultiple() or !self.matches.isPresent(a.id)) return null;
        const disp = if (a.long_name) |l| self.dashed(l) else self.shortDisplay(a.short_char.?);
        return self.mkErr(.argument_used_multiple_times, disp, null);
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
