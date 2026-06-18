const std = @import("std");
const arg = @import("arg.zig");
const arg_group = @import("arg_group.zig");

const Arg = arg.Arg;
const ArgGroup = arg_group.ArgGroup;

/// A command (or subcommand): a name, settings, its arguments, and nested
/// subcommands. Port of clap's `Command`:
/// https://github.com/clap-rs/clap/blob/master/clap_builder/src/builder/command.rs
///
/// Arena-backed builder: `init` stores the allocator, setters chain by value,
/// and append-style methods (`arg`, `args`, `subcommand`) mutate in place.
/// Building is expected at startup, so allocation failure panics rather than
/// threading an error through the fluent chain.
pub const Command = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    bin_name: ?[]const u8 = null,
    about_text: ?[]const u8 = null,
    version_str: ?[]const u8 = null,
    arg_list: std.ArrayListUnmanaged(Arg) = .empty,
    subcommands: std.ArrayListUnmanaged(Command) = .empty,
    groups: std.ArrayListUnmanaged(ArgGroup) = .empty,

    subcommand_required: bool = false,
    arg_required_else_help: bool = false,
    allow_external_subcommands: bool = false,
    args_conflicts_with_subcommands: bool = false,
    flatten_help: bool = false,
    disable_help_flag: bool = false,
    disable_help_subcommand: bool = false,
    disable_version_flag: bool = false,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) Command {
        return .{ .allocator = allocator, .name = name };
    }

    pub fn deinit(self: *Command) void {
        for (self.subcommands.items) |*sc| sc.deinit();
        self.subcommands.deinit(self.allocator);
        self.arg_list.deinit(self.allocator);
        self.groups.deinit(self.allocator);
    }

    // ----- builder setters -----

    pub fn about(self: Command, text: []const u8) Command {
        var c = self;
        c.about_text = text;
        return c;
    }

    pub fn version(self: Command, v: []const u8) Command {
        var c = self;
        c.version_str = v;
        return c;
    }

    /// Whether the auto `-V/--version` flag applies (version set and not disabled).
    pub fn hasVersionFlag(self: *const Command) bool {
        return self.version_str != null and !self.disable_version_flag;
    }

    pub fn binName(self: Command, name: []const u8) Command {
        var c = self;
        c.bin_name = name;
        return c;
    }

    pub fn arg(self: Command, a: Arg) Command {
        var c = self;
        var to_add = a;
        if (to_add.isPositional() and to_add.index == null) {
            to_add.index = c.countPositionals() + 1;
        }
        c.arg_list.append(c.allocator, to_add) catch @panic("clap: OOM building command");
        return c;
    }

    pub fn args(self: Command, list: []const Arg) Command {
        var c = self;
        for (list) |a| c = c.arg(a);
        return c;
    }

    pub fn subcommand(self: Command, cmd: Command) Command {
        var c = self;
        c.subcommands.append(c.allocator, cmd) catch @panic("clap: OOM building command");
        return c;
    }

    pub fn group(self: Command, g: ArgGroup) Command {
        var c = self;
        c.groups.append(c.allocator, g) catch @panic("clap: OOM building command");
        return c;
    }

    pub fn subcommandRequired(self: Command, yes: bool) Command {
        var c = self;
        c.subcommand_required = yes;
        return c;
    }

    pub fn argRequiredElseHelp(self: Command, yes: bool) Command {
        var c = self;
        c.arg_required_else_help = yes;
        return c;
    }

    pub fn allowExternalSubcommands(self: Command, yes: bool) Command {
        var c = self;
        c.allow_external_subcommands = yes;
        return c;
    }

    pub fn argsConflictsWithSubcommands(self: Command, yes: bool) Command {
        var c = self;
        c.args_conflicts_with_subcommands = yes;
        return c;
    }

    pub fn flattenHelp(self: Command, yes: bool) Command {
        var c = self;
        c.flatten_help = yes;
        return c;
    }

    /// Propagate full binary-name paths down the tree (clap's `_build`):
    /// a subcommand's `bin_name` becomes "<parent path> <name>". Call once on the
    /// root before parsing/help so usage lines read e.g. "git stash push".
    pub fn buildTree(self: *Command) void {
        self.propagate(self.bin_name orelse self.name);
    }

    fn propagate(self: *Command, path: []const u8) void {
        self.bin_name = path;
        for (self.subcommands.items) |*sc| {
            const child = std.fmt.allocPrint(self.allocator, "{s} {s}", .{ path, sc.name }) catch
                @panic("clap: OOM building command");
            sc.propagate(child);
        }
    }

    // ----- queries -----

    pub fn displayName(self: *const Command) []const u8 {
        return self.bin_name orelse self.name;
    }

    pub fn countPositionals(self: *const Command) usize {
        var n: usize = 0;
        for (self.arg_list.items) |*a| {
            if (a.isPositional()) n += 1;
        }
        return n;
    }

    pub fn hasSubcommands(self: *const Command) bool {
        return self.subcommands.items.len > 0;
    }

    pub fn findArgByLong(self: *const Command, name: []const u8) ?*const Arg {
        for (self.arg_list.items) |*a| {
            if (a.long_name) |l| {
                if (std.mem.eql(u8, l, name)) return a;
            }
        }
        return null;
    }

    pub fn findArgByShort(self: *const Command, c: u8) ?*const Arg {
        for (self.arg_list.items) |*a| {
            if (a.short_char == c) return a;
        }
        return null;
    }

    pub fn findArgById(self: *const Command, id: []const u8) ?*const Arg {
        for (self.arg_list.items) |*a| {
            if (std.mem.eql(u8, a.id, id)) return a;
        }
        return null;
    }

    pub fn getPositional(self: *const Command, index: usize) ?*const Arg {
        for (self.arg_list.items) |*a| {
            if (a.index == index) return a;
        }
        return null;
    }

    pub fn findSubcommand(self: *const Command, name: []const u8) ?*const Command {
        for (self.subcommands.items) |*sc| {
            if (std.mem.eql(u8, sc.name, name)) return sc;
        }
        return null;
    }

    pub fn findGroup(self: *const Command, id: []const u8) ?*const ArgGroup {
        for (self.groups.items) |*g| {
            if (std.mem.eql(u8, g.id, id)) return g;
        }
        return null;
    }

    /// Whether `a` belongs to group `g` (via `Arg.group()` or `ArgGroup.args()`).
    pub fn argInGroup(self: *const Command, a: *const Arg, g: *const ArgGroup) bool {
        _ = self;
        if (a.group_id) |gid| {
            if (std.mem.eql(u8, gid, g.id)) return true;
        }
        for (g.member_ids) |id| {
            if (std.mem.eql(u8, id, a.id)) return true;
        }
        return false;
    }

    /// Membership by group id — also resolves implicit groups (a group named only
    /// via `Arg.group("x")`, with no `ArgGroup` object).
    pub fn argInGroupId(self: *const Command, a: *const Arg, id: []const u8) bool {
        if (a.group_id) |gid| {
            if (std.mem.eql(u8, gid, id)) return true;
        }
        if (self.findGroup(id)) |g| {
            for (g.member_ids) |m| {
                if (std.mem.eql(u8, m, a.id)) return true;
            }
        }
        return false;
    }

    /// Whether `id` names a group (declared or implicit) rather than an argument.
    pub fn isGroupId(self: *const Command, id: []const u8) bool {
        if (self.findGroup(id) != null) return true;
        for (self.arg_list.items) |*a| {
            if (a.group_id) |gid| {
                if (std.mem.eql(u8, gid, id)) return true;
            }
        }
        return false;
    }

    /// Whether `a` is a member of any `required` group (such args are shown in a
    /// group token in usage rather than under `[OPTIONS]`).
    pub fn argInRequiredGroup(self: *const Command, a: *const Arg) bool {
        for (self.groups.items) |*g| {
            if (g.is_required and self.argInGroup(a, g)) return true;
        }
        return false;
    }
};

const testing = std.testing;

test "command: builds tree and assigns positional indices" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const cmd = Command.init(a, "git")
        .about("A fictional versioning CLI")
        .subcommandRequired(true)
        .subcommand(Command.init(a, "clone")
            .about("Clones repos")
            .arg(Arg.fromUsage("<REMOTE>", "The remote to clone")))
        .subcommand(Command.init(a, "diff")
            .arg(Arg.fromUsage("base: [COMMIT]", null))
            .arg(Arg.fromUsage("head: [COMMIT]", null)));

    try testing.expect(cmd.subcommand_required);
    try testing.expectEqualStrings("A fictional versioning CLI", cmd.about_text.?);
    try testing.expectEqual(@as(usize, 2), cmd.subcommands.items.len);

    const diff = cmd.findSubcommand("diff").?;
    try testing.expectEqual(@as(usize, 1), diff.getPositional(1).?.index.?);
    try testing.expectEqualStrings("base", diff.getPositional(1).?.id);
    try testing.expectEqualStrings("head", diff.getPositional(2).?.id);

    const clone = cmd.findSubcommand("clone").?;
    try testing.expectEqualStrings("REMOTE", clone.findArgById("REMOTE").?.id);
}
