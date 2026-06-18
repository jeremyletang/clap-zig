const std = @import("std");
const command = @import("../builder/command.zig");
const matcher = @import("matcher.zig");
const errors = @import("../error.zig");
const layout = @import("../output/layout.zig");
const arg = @import("../builder/arg.zig");

const Command = command.Command;
const Arg = arg.Arg;
const ArgMatches = matcher.ArgMatches;
const Error = errors.Error;

/// Post-parse validation, applied to a command and its matches recursively.
/// Port of https://github.com/clap-rs/clap/blob/master/clap_builder/src/parser/validator.rs
/// Returns the first failure (or a help-display request), or null if valid.
pub fn validate(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    // `arg_required_else_help` takes precedence: nothing supplied -> show help.
    if (cmd.arg_required_else_help and !m.suppliedAnything()) {
        return .{ .kind = .display_help_on_missing_argument_or_subcommand, .cmd = cmd };
    }
    if (checkPossibleValues(allocator, cmd, m)) |e| return e;
    if (checkRequired(allocator, cmd, m)) |e| return e;
    if (checkSubcommandRequired(cmd, m)) |e| return e;
    return validateSubcommand(allocator, cmd, m);
}

fn checkPossibleValues(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    for (cmd.arg_list.items) |*a| {
        const vals = m.getRaw(a.id) orelse continue;
        for (vals) |v| {
            if (a.possible_values) |allowed| {
                if (!contains(allowed, v)) {
                    return invalidValue(allocator, cmd, a, v, .{ .possible_values = allowed });
                }
            }
            if (a.value_parser_fn) |parse| {
                switch (parse(allocator, v)) {
                    .ok => {},
                    .invalid => |reason| return invalidValue(allocator, cmd, a, v, .{ .reason = reason }),
                }
            }
        }
    }
    return null;
}

const InvalidExtra = struct {
    possible_values: ?[]const []const u8 = null,
    reason: ?[]const u8 = null,
};

fn invalidValue(allocator: std.mem.Allocator, cmd: *const Command, a: *const Arg, value: []const u8, extra: InvalidExtra) Error {
    return .{
        .kind = .invalid_value,
        .cmd = cmd,
        .arg = layout.argUsageStr(allocator, a),
        .value = value,
        .possible_values = extra.possible_values,
        .reason = extra.reason,
    };
}

fn checkRequired(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    for (cmd.arg_list.items) |*a| {
        if (a.required_flag and !m.isPresent(a.id)) {
            return .{ .kind = .missing_required_argument, .cmd = cmd, .arg = layout.argUsageStr(allocator, a) };
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

fn validateSubcommand(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    const sub = m.subcommand() orelse return null;
    // external subcommands have no Command to validate against
    const sub_cmd = cmd.findSubcommand(sub.name) orelse return null;
    return validate(allocator, sub_cmd, sub.matches);
}

fn contains(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |h| {
        if (std.mem.eql(u8, h, needle)) return true;
    }
    return false;
}
