const std = @import("std");
const command = @import("../builder/command.zig");
const arg = @import("../builder/arg.zig");
const layout = @import("layout.zig");

const Command = command.Command;
const Arg = arg.Arg;
const Buf = layout.Buf;
const Parts = std.ArrayListUnmanaged([]const u8);

/// The help usage line, e.g. "Usage: git diff [OPTIONS] [COMMIT] [COMMIT] [-- <PATH>]".
/// Port of https://github.com/clap-rs/clap/blob/master/clap_builder/src/output/usage.rs
pub fn render(allocator: std.mem.Allocator, cmd: *const Command) []const u8 {
    return withHeading(allocator, body(allocator, cmd, &.{}, true));
}

/// Contextual ("smart") usage for an error: `used` is the set of present + missing
/// ids; when non-empty, clap drops the `[OPTIONS]` tag and unrolls the required graph.
pub fn errorUsage(allocator: std.mem.Allocator, cmd: *const Command, used: []const []const u8) []const u8 {
    return withHeading(allocator, body(allocator, cmd, used, true));
}

/// Prefix a usage body with the styled `Usage:` heading.
fn withHeading(allocator: std.mem.Allocator, usage_body: []const u8) []const u8 {
    var b = Buf{ .allocator = allocator };
    b.role(.usage, "Usage:");
    b.addByte(' ');
    b.add(usage_body);
    return b.items();
}

/// The usage body (binary name + args), without the "Usage: " prefix. Used by the
/// flattened help layout, which lists each subcommand on its own line.
pub fn appendBody(allocator: std.mem.Allocator, cmd: *const Command, include_subcommand: bool) []const u8 {
    return body(allocator, cmd, &.{}, include_subcommand);
}

fn body(allocator: std.mem.Allocator, cmd: *const Command, used: []const []const u8, include_subcommand: bool) []const u8 {
    // a multicall command has no bin name of its own: usage is just `<COMMAND>`
    if (cmd.is_multicall) {
        return std.fmt.allocPrint(allocator, "<{s}>", .{cmd.subcommand_value_name orelse "COMMAND"}) catch @panic("clap: OOM");
    }
    var parts: Parts = .empty;
    if (used.len == 0 and needsOptionsTag(cmd)) push(allocator, &parts, "[OPTIONS]");
    collectArgParts(allocator, cmd, used, &parts);
    if (include_subcommand and cmd.hasVisibleSubcommands()) {
        // Help usage lists `[COMMAND]`/`<COMMAND>`; smart (error) usage only
        // shows the subcommand slot when one is required (clap's write_smart_usage).
        const cn = cmd.subcommand_value_name orelse "COMMAND";
        if (used.len == 0) {
            const slot = if (cmd.subcommand_required)
                std.fmt.allocPrint(allocator, "<{s}>", .{cn}) catch @panic("clap: OOM")
            else
                std.fmt.allocPrint(allocator, "[{s}]", .{cn}) catch @panic("clap: OOM");
            push(allocator, &parts, slot);
        } else if (cmd.subcommand_required) {
            push(allocator, &parts, std.fmt.allocPrint(allocator, "<{s}>", .{cn}) catch @panic("clap: OOM"));
        }
    }

    var b = Buf{ .allocator = allocator };
    b.role(.literal, cmd.usageName(allocator));
    for (parts.items) |p| {
        b.addByte(' ');
        b.add(p);
    }
    return b.items();
}

/// clap's `write_args`: required options, then required groups, then positionals.
fn collectArgParts(allocator: std.mem.Allocator, cmd: *const Command, used: []const []const u8, parts: *Parts) void {
    var candidates: Parts = .empty;
    for (cmd.groups.items) |*g| {
        if (g.is_required) pushUnique(allocator, &candidates, g.id);
    }
    for (cmd.arg_list.items) |*a| {
        if (a.required_flag) pushUnique(allocator, &candidates, a.id);
    }
    for (used) |id| pushUnique(allocator, &candidates, id);

    var members: Parts = .empty;
    var groups: Parts = .empty;
    for (candidates.items) |id| {
        if (!cmd.isGroupId(id)) continue;
        push(allocator, &groups, layout.groupNotation(allocator, cmd, id));
        for (cmd.arg_list.items) |*a| {
            if (cmd.argInGroupId(a, id)) pushUnique(allocator, &members, a.id);
        }
    }

    var opts: Parts = .empty;
    for (candidates.items) |id| {
        if (cmd.isGroupId(id)) continue;
        const a = cmd.findArgById(id) orelse continue;
        if (a.isPositional() or contains(members.items, a.id)) continue;
        // multiple-valued options carry a trailing `...` in usage (clap's stylized)
        push(allocator, &opts, layout.conflictDisplay(allocator, a));
    }

    for (opts.items) |p| push(allocator, parts, p);
    for (groups.items) |p| push(allocator, parts, p);
    appendPositionals(allocator, cmd, members.items, used, parts);
}

fn appendPositionals(allocator: std.mem.Allocator, cmd: *const Command, members: []const []const u8, used: []const []const u8, parts: *Parts) void {
    var i: usize = 1;
    while (cmd.getPositional(i)) |a| : (i += 1) {
        if (contains(members, a.id) or a.is_hidden) continue;
        // A positional pulled into `used` (e.g. it was supplied and is named in a
        // conflict's usage) is forced to the required `<NAME>` form, matching
        // clap's `stylized(Some(true))` for incls.
        const force_required = contains(used, a.id);
        if (a.last_flag) {
            // required last -> `-- <X>...`; optional last -> `[-- <X>...]`
            var b = Buf{ .allocator = allocator };
            b.add(if (a.required_flag or force_required) "-- <" else "[-- <");
            b.add(a.value_name orelse a.id);
            b.add(">");
            if (a.showsEllipsis()) b.add("...");
            if (!(a.required_flag or force_required)) b.add("]");
            push(allocator, parts, b.items());
        } else if (force_required and !a.required_flag) {
            var b = Buf{ .allocator = allocator };
            b.add("<");
            b.add(a.value_name orelse a.id);
            b.add(">");
            if (a.showsEllipsis()) b.add("...");
            push(allocator, parts, b.items());
        } else {
            push(allocator, parts, layout.positionalNotationStr(allocator, a));
        }
    }
}

/// Whether `[OPTIONS]` is needed: some non-positional arg exists that isn't
/// help/version (those aren't in arg_list) and isn't in a required group.
pub fn needsOptionsTag(cmd: *const Command) bool {
    for (cmd.arg_list.items) |*a| {
        if (a.isPositional() or a.is_hidden) continue;
        if (a.is_global) continue; // global args don't trigger the local `[OPTIONS]` tag
        // help/version-action flags don't count toward `[OPTIONS]`
        switch (a.action_val) {
            .help, .help_short, .help_long, .version => continue,
            else => {},
        }
        if (cmd.argInRequiredGroup(a)) continue;
        return true;
    }
    return false;
}

fn push(allocator: std.mem.Allocator, parts: *Parts, s: []const u8) void {
    parts.append(allocator, s) catch @panic("clap: OOM rendering output");
}

fn pushUnique(allocator: std.mem.Allocator, parts: *Parts, s: []const u8) void {
    if (!contains(parts.items, s)) push(allocator, parts, s);
}

fn contains(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |h| {
        if (std.mem.eql(u8, h, needle)) return true;
    }
    return false;
}
