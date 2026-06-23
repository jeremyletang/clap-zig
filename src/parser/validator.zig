const std = @import("std");
const command = @import("../builder/command.zig");
const matcher = @import("matcher.zig");
const errors = @import("../error.zig");
const layout = @import("../output/layout.zig");
const arg = @import("../builder/arg.zig");
const suggest = @import("../suggest.zig");

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
    if (checkArgConflicts(allocator, cmd, m)) |e| return e;
    if (checkGroupConflicts(allocator, cmd, m)) |e| return e;
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

/// Mutual-exclusion declared via `conflicts_with` / `conflicts_with_all` /
/// `exclusive`. Conflicts are symmetric: report the first present arg (in
/// definition order) that conflicts with one or more other present args, listing
/// those conflicting args in definition order. Port of clap's conflict checking
/// in https://github.com/clap-rs/clap/blob/master/clap_builder/src/parser/validator.rs
fn checkArgConflicts(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    const ordered = presentInParseOrder(allocator, cmd, m);
    for (ordered) |a| {
        var others: std.ArrayListUnmanaged(*const Arg) = .empty;
        for (ordered) |b| {
            if (b == a) continue;
            if (conflicts(a, b)) others.append(allocator, b) catch @panic("clap: OOM");
        }
        if (others.items.len == 0) continue;

        var disp: std.ArrayListUnmanaged([]const u8) = .empty;
        var conflict_ids: Ids = .empty;
        for (others.items) |b| {
            disp.append(allocator, layout.conflictDisplay(allocator, b)) catch @panic("clap: OOM");
            conflict_ids.append(allocator, b.id) catch @panic("clap: OOM");
        }
        // Usage drops the conflicting args themselves, then pulls in any args
        // `require`d by what's left (clap's build_conflict_err_usage).
        var used: Ids = .empty;
        for (m.presentIds(allocator)) |id| {
            if (!contains(conflict_ids.items, id)) used.append(allocator, id) catch @panic("clap: OOM");
        }
        for (used.items) |id| {
            const u = cmd.findArgById(id) orelse continue;
            const req = u.requires_id orelse continue;
            if (!contains(conflict_ids.items, req) and !contains(used.items, req)) {
                used.append(allocator, req) catch @panic("clap: OOM");
            }
        }
        return .{
            .kind = .argument_conflict,
            .cmd = cmd,
            .arg = layout.conflictDisplay(allocator, a),
            .conflicts = disp.items,
            .used_ids = used.items,
        };
    }
    return null;
}

/// Present args (CLI source only) ordered by their first parse index — clap's
/// matcher iterates in insertion order, so the conflict subject is the
/// earliest-supplied of a conflicting pair.
fn presentInParseOrder(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) []*const Arg {
    var list: std.ArrayListUnmanaged(*const Arg) = .empty;
    for (cmd.arg_list.items) |*a| {
        if (m.isPresent(a.id)) list.append(allocator, a) catch @panic("clap: OOM");
    }
    const items = list.items;
    std.sort.insertion(*const Arg, items, m, lessByIndex);
    return items;
}

fn lessByIndex(m: *const ArgMatches, a: *const Arg, b: *const Arg) bool {
    const ia = m.indexOf(a.id) orelse 0;
    const ib = m.indexOf(b.id) orelse 0;
    return ia < ib;
}

/// Whether two args conflict: either declares the other in its `conflicts_with`
/// list, or either is `exclusive` (conflicts with everything).
fn conflicts(a: *const Arg, b: *const Arg) bool {
    if (a.is_exclusive or b.is_exclusive) return true;
    if (a.conflicts_with) |list| {
        if (contains(list, b.id)) return true;
    }
    if (b.conflicts_with) |list| {
        if (contains(list, a.id)) return true;
    }
    return false;
}

/// A required-but-absent arg is satisfiable if it conflicts with — or is
/// overridden by — some present arg (clap's `is_missing_required_ok`, where
/// overrides count as implicit conflicts).
fn missingRequiredOk(cmd: *const Command, m: *const ArgMatches, a: *const Arg) bool {
    for (cmd.arg_list.items) |*b| {
        if (b == a or !m.isPresent(b.id)) continue;
        if (conflicts(a, b) or overrides(a, b)) return true;
    }
    return false;
}

/// Whether either arg lists the other in its `overrides_with` set.
fn overrides(a: *const Arg, b: *const Arg) bool {
    if (a.overrides) |list| {
        if (contains(list, b.id)) return true;
    }
    if (b.overrides) |list| {
        if (contains(list, a.id)) return true;
    }
    return false;
}

/// A non-`multiple` group whose members are mutually exclusive: report the first
/// two present members.
fn checkGroupConflicts(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    for (groupIds(allocator, cmd)) |id| {
        if (groupIsMultiple(cmd, id)) continue;
        const present = presentMembers(allocator, cmd, m, id);
        if (present.len < 2) continue;
        const others = allocator.dupe([]const u8, &.{layout.argUsageStr(allocator, present[1])}) catch @panic("clap: OOM");
        return .{
            .kind = .argument_conflict,
            .cmd = cmd,
            .arg = layout.argUsageStr(allocator, present[0]),
            .conflicts = others,
            .used_ids = m.presentIds(allocator),
        };
    }
    return null;
}

/// Required-argument validation. Port of clap's `validate_required`/
/// `gather_requires`/`missing_required_error`: builds the relevant-required set
/// (base-required args & groups, their unconditionally-unrolled `requires`, plus
/// `requires`/`requires_if` pulled in by present args), then reports every
/// member that is absent in one error — listing them in usage order and rendering
/// a contextual usage line.
fn checkRequired(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) ?Error {
    // A present `exclusive` arg waives every other requirement.
    for (cmd.arg_list.items) |*a| {
        if (a.is_exclusive and m.isPresent(a.id)) return null;
    }

    const relevant = gatherRequired(allocator, cmd, m);

    var missing: Ids = .empty;
    var highest_index: usize = 0;
    for (relevant) |id| {
        if (cmd.isGroupId(id)) {
            if (presentMembers(allocator, cmd, m, id).len == 0) pushUnique(allocator, &missing, id);
            continue;
        }
        const a = cmd.findArgById(id) orelse continue;
        if (m.isPresent(a.id) or missingRequiredOk(cmd, m, a)) continue;
        pushUnique(allocator, &missing, id);
        if (!a.last_flag) highest_index = @max(highest_index, a.index orelse 0);
    }

    // Conditionally-required args (required_unless_present / _any / _all; later
    // required_if_eq). clap's second validate_required loop over absent args.
    for (cmd.arg_list.items) |*a| {
        if (m.isPresent(a.id) or !conditionallyRequired(m, a)) continue;
        pushUnique(allocator, &missing, a.id);
        if (!a.last_flag) highest_index = @max(highest_index, a.index orelse 0);
    }

    // For display continuity, include any absent positional preceding a missing one.
    var i: usize = 1;
    while (cmd.getPositional(i)) |p| : (i += 1) {
        if (p.index.? < highest_index and !m.isPresent(p.id)) pushUnique(allocator, &missing, p.id);
    }

    if (missing.items.len == 0) return null;
    return missingRequiredError(allocator, cmd, m, relevant, missing.items);
}

/// The relevant-required id set (args + group ids), in clap's order: base-required
/// args, required groups, each unrolled through its `requires` graph
/// unconditionally, then `requires`/`requires_if` contributed by present args.
fn gatherRequired(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) [][]const u8 {
    var ids: Ids = .empty;
    for (cmd.arg_list.items) |*a| {
        if (a.required_flag) unrollRequires(allocator, cmd, m, a, &ids);
    }
    for (cmd.groups.items) |*g| {
        if (g.is_required) pushUnique(allocator, &ids, g.id);
    }
    // Present args contribute the targets they require (not themselves).
    for (cmd.arg_list.items) |*a| {
        if (!m.isPresent(a.id)) continue;
        if (a.requires_id) |req| addRequired(allocator, cmd, m, req, &ids);
        if (a.requires_ifs) |conds| {
            for (conds) |c| {
                if (valueMatches(m, a.id, c.value)) addRequired(allocator, cmd, m, c.target, &ids);
            }
        }
    }
    return ids.items;
}

/// Add `a` and the args it requires to `ids`, recursing through their `requires`.
/// `requires` (IsPresent) edges are followed unconditionally; `requires_if`
/// (Equals) edges only when `a` is present holding the paired value.
fn unrollRequires(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches, a: *const Arg, ids: *Ids) void {
    pushUnique(allocator, ids, a.id);
    if (a.requires_id) |req| addRequired(allocator, cmd, m, req, ids);
    if (m.isPresent(a.id)) {
        if (a.requires_ifs) |conds| {
            for (conds) |c| {
                if (valueMatches(m, a.id, c.value)) addRequired(allocator, cmd, m, c.target, ids);
            }
        }
    }
}

/// Add a required target id, recursing into its own `requires` (args only;
/// group ids are added as-is, their members enumerated at report time).
fn addRequired(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches, id: []const u8, ids: *Ids) void {
    if (contains(ids.items, id)) return;
    if (cmd.findArgById(id)) |t| {
        unrollRequires(allocator, cmd, m, t, ids);
    } else {
        pushUnique(allocator, ids, id);
    }
}

/// Whether an absent arg is made required by any conditional mechanism:
/// `required_if_eq(_any/_all)` (another arg holds a value) or
/// `required_unless_present(_any/_all)` (named args absent). Port of clap's
/// conditional `validate_required` loop (`r_ifs`, `r_ifs_all`, `r_unless`).
fn conditionallyRequired(m: *const ArgMatches, a: *const Arg) bool {
    // required_if_eq_any: any matching pair triggers.
    if (a.required_if_eq_any) |any| {
        for (any) |c| {
            if (valueMatches(m, c.target, c.value)) return true;
        }
    }
    // required_if_eq_all: every pair must match (and the list be non-empty).
    if (a.required_if_eq_all) |all| {
        var match_all = all.len != 0;
        for (all) |c| {
            if (!valueMatches(m, c.target, c.value)) match_all = false;
        }
        if (match_all) return true;
    }
    // required_unless_present(_any/_all): required when its conditions are unmet.
    if (a.required_unless_any != null or a.required_unless_all != null) {
        if (failsRequiredUnless(m, a)) return true;
    }
    return false;
}

/// clap's `fails_arg_required_unless`: the `required_unless` conditions are unmet
/// when none of the any-list is present and not all of the all-list is present.
fn failsRequiredUnless(m: *const ArgMatches, a: *const Arg) bool {
    if (a.required_unless_any) |any| {
        for (any) |id| {
            if (m.isPresent(id)) return false;
        }
    }
    if (a.required_unless_all) |all| {
        var all_present = true;
        for (all) |id| {
            if (!m.isPresent(id)) all_present = false;
        }
        if (all.len != 0 and all_present) return false;
    }
    return true;
}

fn valueMatches(m: *const ArgMatches, id: []const u8, value: []const u8) bool {
    const vals = m.getRaw(id) orelse return false;
    return contains(vals, value);
}

/// Build the single missing-required error: the absent ids listed in usage order
/// (options, groups, positionals) and a usage line over present ∪ missing.
fn missingRequiredError(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches, relevant: []const []const u8, missing: []const []const u8) Error {
    var lines: std.ArrayListUnmanaged(u8) = .empty;
    for (orderedMissing(allocator, cmd, missing), 0..) |disp, idx| {
        if (idx != 0) lines.appendSlice(allocator, "\n  ") catch @panic("clap: OOM");
        lines.appendSlice(allocator, disp) catch @panic("clap: OOM");
    }
    // clap's usage processes the required graph (+gathered) first, then the
    // present args, then the remaining missing — so opt ordering matches.
    var used: Ids = .empty;
    for (relevant) |id| pushUnique(allocator, &used, id);
    for (presentInDefOrder(allocator, cmd, m)) |id| pushUnique(allocator, &used, id);
    for (missing) |id| pushUnique(allocator, &used, id);
    return .{
        .kind = .missing_required_argument,
        .cmd = cmd,
        .arg = lines.items,
        .used_ids = used.items,
    };
}

/// The missing ids as display strings in clap's report order: options, then
/// groups (absorbing their members), then positionals by index.
fn orderedMissing(allocator: std.mem.Allocator, cmd: *const Command, missing: []const []const u8) [][]const u8 {
    var out: std.ArrayListUnmanaged([]const u8) = .empty;
    var absorbed: Ids = .empty;
    for (missing) |id| {
        if (!cmd.isGroupId(id)) continue;
        for (cmd.arg_list.items) |*a| {
            if (cmd.argInGroupId(a, id)) pushUnique(allocator, &absorbed, a.id);
        }
    }
    for (missing) |id| {
        if (cmd.isGroupId(id) or contains(absorbed.items, id)) continue;
        const a = cmd.findArgById(id) orelse continue;
        if (a.isPositional()) continue;
        out.append(allocator, layout.argUsageStr(allocator, a)) catch @panic("clap: OOM");
    }
    for (missing) |id| {
        if (!cmd.isGroupId(id)) continue;
        out.append(allocator, layout.groupNotation(allocator, cmd, id)) catch @panic("clap: OOM");
    }
    var i: usize = 1;
    while (cmd.getPositional(i)) |p| : (i += 1) {
        if (!contains(missing, p.id) or contains(absorbed.items, p.id)) continue;
        // clap renders missing positionals in required `<NAME>` form regardless
        // of their own optionality (`stylized(Some(true))`).
        out.append(allocator, requiredPositional(allocator, p)) catch @panic("clap: OOM");
    }
    return out.items;
}

fn requiredPositional(allocator: std.mem.Allocator, a: *const Arg) []const u8 {
    const name = a.value_name orelse a.id;
    if (a.showsEllipsis()) return std.fmt.allocPrint(allocator, "<{s}>...", .{name}) catch @panic("clap: OOM");
    return std.fmt.allocPrint(allocator, "<{s}>", .{name}) catch @panic("clap: OOM");
}

fn presentInDefOrder(allocator: std.mem.Allocator, cmd: *const Command, m: *const ArgMatches) [][]const u8 {
    var ids: Ids = .empty;
    for (cmd.arg_list.items) |*a| {
        if (m.isPresent(a.id)) ids.append(allocator, a.id) catch @panic("clap: OOM");
    }
    return ids.items;
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
    var suggestions: ?[]const []const u8 = null;
    if (extra.possible_values) |pv| {
        const cands = suggest.didYouMean(allocator, value, pv);
        if (cands.len != 0) suggestions = cands;
    }
    return .{
        .kind = .invalid_value,
        .cmd = cmd,
        .arg = layout.argUsageStr(allocator, a),
        .value = value,
        .possible_values = extra.possible_values,
        .reason = extra.reason,
        .suggestions = suggestions,
    };
}
