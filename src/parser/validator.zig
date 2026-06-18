const std = @import("std");
const command = @import("../builder/command.zig");
const matcher = @import("matcher.zig");
const errors = @import("../error.zig");
const layout = @import("../output/layout.zig");
const arg = @import("../builder/arg.zig");

const Command = command.Command;
const ArgMatches = matcher.ArgMatches;
const Error = errors.Error;
const Arg = arg.Arg;
const Ids = std.ArrayListUnmanaged([]const u8);

/// Post-parse validation, applied to a command and its matches recursively.
/// Port of https://github.com/clap-rs/clap/blob/master/clap_builder/src/parser/validator.rs
pub fn validate(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    if (cmd.arg_required_else_help and !m.suppliedAnything()) {
        return .{ .kind = .display_help_on_missing_argument_or_subcommand, .cmd = cmd };
    }
    if (checkPossibleValues(allocator, cmd, m)) |e| return e;
    if (checkGroupConflicts(allocator, cmd, m)) |e| return e;
    if (checkRequiredGroups(allocator, cmd, m)) |e| return e;
    if (checkRequires(allocator, cmd, m)) |e| return e;
    if (checkRequired(allocator, cmd, m)) |e| return e;
    if (checkSubcommandRequired(cmd, m)) |e| return e;
    return validateSubcommand(allocator, cmd, m);
}

fn checkPossibleValues(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    for (cmd.arg_list.items) |*a| {
        const vals = m.getRaw(a.id) orelse continue;
        for (vals) |v| {
            if (a.possibleValueNames(allocator)) |allowed| {
                if (!contains(allowed, v)) return invalidValue(allocator, cmd, a, v, .{ .possible_values = allowed });
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

/// A non-`multiple` group whose members are mutually exclusive: report the first
/// two present members.
fn checkGroupConflicts(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    for (groupIds(allocator, cmd)) |id| {
        if (groupIsMultiple(cmd, id)) continue;
        const present = presentMembers(allocator, cmd, m, id);
        if (present.len < 2) continue;
        return .{
            .kind = .argument_conflict,
            .cmd = cmd,
            .arg = layout.argUsageStr(allocator, present[0]),
            .value = layout.argUsageStr(allocator, present[1]),
            .used_ids = m.presentIds(allocator),
        };
    }
    return null;
}

fn checkRequiredGroups(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    for (cmd.groups.items) |*g| {
        if (!g.is_required) continue;
        if (presentMembers(allocator, cmd, m, g.id).len != 0) continue;
        return missingGroup(allocator, cmd, m, g.id);
    }
    return null;
}

fn checkRequires(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    for (cmd.arg_list.items) |*a| {
        const req = a.requires_id orelse continue;
        if (!m.isPresent(a.id)) continue;
        const satisfied = if (cmd.isGroupId(req)) presentMembers(allocator, cmd, m, req).len != 0 else m.isPresent(req);
        if (!satisfied) return missingGroup(allocator, cmd, m, req);
    }
    return null;
}

fn checkRequired(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    for (cmd.arg_list.items) |*a| {
        if (a.required_flag and !m.isPresent(a.id)) {
            return .{
                .kind = .missing_required_argument,
                .cmd = cmd,
                .arg = layout.argUsageStr(allocator, a),
                .used_ids = withId(allocator, m.presentIds(allocator), a.id),
            };
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
    const sub_cmd = cmd.findSubcommand(sub.name) orelse return null; // external: nothing to validate
    return validate(allocator, sub_cmd, sub.matches);
}

// ----- helpers -----

fn missingGroup(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches, id: []const u8) Error {
    return .{
        .kind = .missing_required_argument,
        .cmd = cmd,
        .arg = layout.groupNotation(allocator, cmd, id),
        .used_ids = withId(allocator, m.presentIds(allocator), id),
    };
}

/// Member args of a group (by id) that are present on the command line, in
/// definition order.
fn presentMembers(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches, id: []const u8) []*const Arg {
    var list: std.ArrayListUnmanaged(*const Arg) = .empty;
    for (cmd.arg_list.items) |*a| {
        if (cmd.argInGroupId(a, id) and m.isPresent(a.id)) list.append(allocator, a) catch @panic("clap: OOM");
    }
    return list.items;
}

/// All group ids (declared first, then implicit ones referenced via `Arg.group()`).
fn groupIds(allocator: std.mem.Allocator, cmd: *const Command) [][]const u8 {
    var ids: Ids = .empty;
    for (cmd.groups.items) |*g| pushUnique(allocator, &ids, g.id);
    for (cmd.arg_list.items) |*a| {
        if (a.group_id) |gid| pushUnique(allocator, &ids, gid);
    }
    return ids.items;
}

fn groupIsMultiple(cmd: *const Command, id: []const u8) bool {
    if (cmd.findGroup(id)) |g| return g.is_multiple;
    return false; // implicit groups are exclusive
}

fn withId(allocator: std.mem.Allocator, base: [][]const u8, id: []const u8) [][]const u8 {
    var list: Ids = .empty;
    list.appendSlice(allocator, base) catch @panic("clap: OOM");
    list.append(allocator, id) catch @panic("clap: OOM");
    return list.items;
}

fn pushUnique(allocator: std.mem.Allocator, ids: *Ids, s: []const u8) void {
    if (!contains(ids.items, s)) ids.append(allocator, s) catch @panic("clap: OOM");
}

fn contains(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |h| {
        if (std.mem.eql(u8, h, needle)) return true;
    }
    return false;
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
