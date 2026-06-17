const std = @import("std");
const command = @import("../builder/command.zig");
const arg = @import("../builder/arg.zig");
const matcher = @import("matcher.zig");
const errors = @import("../error.zig");

const Command = command.Command;
const Arg = arg.Arg;
const ArgMatches = matcher.ArgMatches;
const Error = errors.Error;

/// Post-parse validation, applied to a command and its matches recursively.
/// Port of https://github.com/clap-rs/clap/blob/master/clap_builder/src/parser/validator.rs
/// Returns the first failure (or a help-display request), or null if valid.
pub fn validate(cmd: *const Command, m: *const ArgMatches) ?Error {
    // `arg_required_else_help` takes precedence: nothing supplied -> show help.
    if (cmd.arg_required_else_help and !m.suppliedAnything()) {
        return .{ .kind = .display_help_on_missing_argument_or_subcommand, .cmd = cmd };
    }
    if (checkPossibleValues(cmd, m)) |e| return e;
    if (checkRequired(cmd, m)) |e| return e;
    if (checkSubcommandRequired(cmd, m)) |e| return e;
    return validateSubcommand(cmd, m);
}

fn checkPossibleValues(cmd: *const Command, m: *const ArgMatches) ?Error {
    for (cmd.arg_list.items) |*a| {
        const vals = m.getRaw(a.id) orelse continue;
        const allowed = a.possible_values orelse continue;
        for (vals) |v| {
            if (!contains(allowed, v)) {
                return .{ .kind = .invalid_value, .cmd = cmd, .arg = argName(a), .value = v };
            }
        }
    }
    return null;
}

fn checkRequired(cmd: *const Command, m: *const ArgMatches) ?Error {
    for (cmd.arg_list.items) |*a| {
        if (a.required_flag and !m.isPresent(a.id)) {
            return .{ .kind = .missing_required_argument, .cmd = cmd, .arg = argName(a) };
        }
    }
    return null;
}

fn checkSubcommandRequired(cmd: *const Command, m: *const ArgMatches) ?Error {
    if (cmd.subcommand_required and cmd.hasSubcommands() and m.subcommand() == null) {
        return .{ .kind = .missing_subcommand, .cmd = cmd };
    }
    return null;
}

fn validateSubcommand(cmd: *const Command, m: *const ArgMatches) ?Error {
    const sub = m.subcommand() orelse return null;
    // external subcommands have no Command to validate against
    const sub_cmd = cmd.findSubcommand(sub.name) orelse return null;
    return validate(sub_cmd, sub.matches);
}

fn contains(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |h| {
        if (std.mem.eql(u8, h, needle)) return true;
    }
    return false;
}

fn argName(a: *const Arg) []const u8 {
    if (a.long_name) |l| return l;
    if (a.value_name) |v| return v;
    return a.id;
}
