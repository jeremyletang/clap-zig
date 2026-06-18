const std = @import("std");
const value_parser = @import("../builder/value_parser.zig");

/// Where a stored value came from (precedence: command_line > default_value).
/// Port of https://github.com/clap-rs/clap/blob/master/clap_builder/src/parser/matches/value_source.rs
pub const ValueSource = enum { default_value, command_line };

/// Accumulated values for a single argument id.
pub const MatchedArg = struct {
    values: std.ArrayListUnmanaged([]const u8) = .empty,
    source: ValueSource = .command_line,
    occurrences: usize = 0,
};

pub const Subcommand = struct {
    name: []const u8,
    matches: *ArgMatches,
};

/// The result of parsing: matched values per arg id plus an optional matched
/// subcommand. Arena-allocated; `deinit` is provided for the non-arena path.
/// Port of clap's `ArgMatches`:
/// https://github.com/clap-rs/clap/blob/master/clap_builder/src/parser/matches/arg_matches.rs
pub const ArgMatches = struct {
    allocator: std.mem.Allocator,
    map: std.StringHashMapUnmanaged(MatchedArg) = .empty,
    sub: ?Subcommand = null,

    pub fn create(allocator: std.mem.Allocator) !*ArgMatches {
        const self = try allocator.create(ArgMatches);
        self.* = .{ .allocator = allocator };
        return self;
    }

    pub fn deinit(self: *ArgMatches) void {
        var it = self.map.valueIterator();
        while (it.next()) |m| m.values.deinit(self.allocator);
        self.map.deinit(self.allocator);
        if (self.sub) |s| s.matches.deinit();
    }

    // ----- mutation (used by the parser) -----

    fn getOrPut(self: *ArgMatches, id: []const u8) *MatchedArg {
        const gop = self.map.getOrPut(self.allocator, id) catch @panic("clap: OOM matching");
        if (!gop.found_existing) gop.value_ptr.* = .{};
        return gop.value_ptr;
    }

    /// Record that `id` occurred (a flag/option/positional was seen).
    pub fn startOccurrence(self: *ArgMatches, id: []const u8, source: ValueSource) void {
        const m = self.getOrPut(id);
        m.occurrences += 1;
        if (source == .command_line) m.source = .command_line;
    }

    pub fn pushValue(self: *ArgMatches, id: []const u8, val: []const u8) void {
        const m = self.getOrPut(id);
        m.values.append(self.allocator, val) catch @panic("clap: OOM matching");
    }

    /// Seed a default value (only if the arg is otherwise absent).
    pub fn setDefault(self: *ArgMatches, id: []const u8, val: []const u8) void {
        if (self.map.contains(id)) return;
        const m = self.getOrPut(id);
        m.source = .default_value;
        m.values.append(self.allocator, val) catch @panic("clap: OOM matching");
    }

    pub fn setSubcommand(self: *ArgMatches, name: []const u8, matches: *ArgMatches) void {
        self.sub = .{ .name = name, .matches = matches };
    }

    // ----- retrieval -----

    /// Whether the argument was supplied on the command line (defaults don't count).
    pub fn isPresent(self: *const ArgMatches, id: []const u8) bool {
        const m = self.map.getPtr(id) orelse return false;
        return m.source == .command_line;
    }

    pub fn contains(self: *const ArgMatches, id: []const u8) bool {
        return self.map.contains(id);
    }

    pub fn getRaw(self: *const ArgMatches, id: []const u8) ?[]const []const u8 {
        const m = self.map.getPtr(id) orelse return null;
        if (m.values.items.len == 0) return null;
        return m.values.items;
    }

    pub fn getOne(self: *const ArgMatches, comptime T: type, id: []const u8) ?T {
        const vals = self.getRaw(id) orelse return null;
        return value_parser.parse(T, vals[0]) catch null;
    }

    pub fn getMany(self: *const ArgMatches, comptime T: type, id: []const u8) ?[]const T {
        const vals = self.getRaw(id) orelse return null;
        if (T == []const u8) return vals;
        @compileError("typed getMany lands in milestone 2; use []const u8 or getOne in a loop");
    }

    pub fn getFlag(self: *const ArgMatches, id: []const u8) bool {
        return self.getOne(bool, id) orelse false;
    }

    /// Number of occurrences of a `Count`-action argument (0 if absent).
    pub fn getCount(self: *const ArgMatches, id: []const u8) usize {
        const m = self.map.getPtr(id) orelse return 0;
        return m.occurrences;
    }

    pub fn subcommand(self: *const ArgMatches) ?Subcommand {
        return self.sub;
    }

    /// Whether this command saw any command-line arg or subcommand (defaults
    /// don't count) — used by `arg_required_else_help`.
    pub fn suppliedAnything(self: *const ArgMatches) bool {
        if (self.sub != null) return true;
        var it = self.map.valueIterator();
        while (it.next()) |m| {
            if (m.source == .command_line) return true;
        }
        return false;
    }
};

const testing = std.testing;

test "matches: store and retrieve values" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const m = try ArgMatches.create(arena.allocator());

    m.startOccurrence("color", .command_line);
    m.pushValue("color", "never");
    try testing.expectEqualStrings("never", m.getOne([]const u8, "color").?);
    try testing.expect(m.isPresent("color"));
    try testing.expect(m.getOne([]const u8, "missing") == null);

    m.pushValue("PATH", "a.txt");
    m.pushValue("PATH", "b.txt");
    const paths = m.getMany([]const u8, "PATH").?;
    try testing.expectEqual(@as(usize, 2), paths.len);
    try testing.expectEqualStrings("b.txt", paths[1]);
}

test "matches: defaults do not count as present" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const m = try ArgMatches.create(arena.allocator());

    m.setDefault("color", "auto");
    try testing.expectEqualStrings("auto", m.getOne([]const u8, "color").?);
    try testing.expect(!m.isPresent("color"));
    try testing.expect(m.contains("color"));
}
