const std = @import("std");
const value_parser = @import("../builder/value_parser.zig");

/// Where a stored value came from (precedence: command_line > env > default_value).
/// `env`/`command_line` are "explicit" (clap's `is_explicit`); only a default is not.
/// Port of https://github.com/clap-rs/clap/blob/master/clap_builder/src/parser/matches/value_source.rs
pub const ValueSource = enum { default_value, env, command_line };

/// Accumulated values for a single argument id, plus the parse-index of each
/// (clap's `cur_idx`: flag-char and value slots counted 1-based, binary = 0).
pub const MatchedArg = struct {
    values: std.ArrayListUnmanaged([]const u8) = .empty,
    indices: std.ArrayListUnmanaged(usize) = .empty,
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
        while (it.next()) |m| {
            m.values.deinit(self.allocator);
            m.indices.deinit(self.allocator);
        }
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

    pub fn pushValue(self: *ArgMatches, id: []const u8, val: []const u8, index: usize) void {
        const m = self.getOrPut(id);
        m.values.append(self.allocator, val) catch @panic("clap: OOM matching");
        m.indices.append(self.allocator, index) catch @panic("clap: OOM matching");
    }

    /// Seed a default value (only if the arg is otherwise absent).
    pub fn setDefault(self: *ArgMatches, id: []const u8, val: []const u8, index: usize) void {
        if (self.map.contains(id)) return;
        const m = self.getOrPut(id);
        m.source = .default_value;
        m.values.append(self.allocator, val) catch @panic("clap: OOM matching");
        m.indices.append(self.allocator, index) catch @panic("clap: OOM matching");
    }

    /// Seed multiple default values (only if the arg is otherwise absent),
    /// indexed from `first_index`. Used by conditional defaults.
    pub fn setDefaults(self: *ArgMatches, id: []const u8, vals: []const []const u8, first_index: usize) void {
        if (self.map.contains(id)) return;
        const m = self.getOrPut(id);
        m.source = .default_value;
        for (vals, 0..) |v, i| {
            m.values.append(self.allocator, v) catch @panic("clap: OOM matching");
            m.indices.append(self.allocator, first_index + i) catch @panic("clap: OOM matching");
        }
    }

    /// Seed value(s) from an environment variable (only if otherwise absent).
    /// Higher precedence than a default, lower than the command line.
    pub fn setEnv(self: *ArgMatches, id: []const u8, vals: []const []const u8, first_index: usize) void {
        if (self.map.contains(id)) return;
        const m = self.getOrPut(id);
        m.source = .env;
        for (vals, 0..) |v, i| {
            m.values.append(self.allocator, v) catch @panic("clap: OOM matching");
            m.indices.append(self.allocator, first_index + i) catch @panic("clap: OOM matching");
        }
    }

    /// Clear a prior occurrence so it can be re-recorded (clap's `args_override_self`).
    pub fn reset(self: *ArgMatches, id: []const u8) void {
        if (self.map.getPtr(id)) |m| {
            m.values.clearRetainingCapacity();
            m.indices.clearRetainingCapacity();
            m.occurrences = 0;
        }
    }

    /// Remove an argument's match entirely (clap's `matcher.remove`, used by
    /// `overrides_with` to drop a superseded arg).
    pub fn remove(self: *ArgMatches, id: []const u8) void {
        if (self.map.fetchRemove(id)) |kv| {
            var m = kv.value;
            m.values.deinit(self.allocator);
            m.indices.deinit(self.allocator);
        }
    }

    /// Clear stored values/indices but keep the occurrence count (clap's `Count`
    /// replaces its value each time while still counting every occurrence).
    pub fn clearValues(self: *ArgMatches, id: []const u8) void {
        if (self.map.getPtr(id)) |m| {
            m.values.clearRetainingCapacity();
            m.indices.clearRetainingCapacity();
        }
    }

    pub fn setSubcommand(self: *ArgMatches, name: []const u8, matches: *ArgMatches) void {
        self.sub = .{ .name = name, .matches = matches };
    }

    /// Copy a global arg's match from `from` into self (overwriting), so a global
    /// arg matched at one level is visible at another.
    pub fn copyMatched(self: *ArgMatches, id: []const u8, from: *const ArgMatches) void {
        const src = from.map.getPtr(id) orelse return;
        const m = self.getOrPut(id);
        m.values.clearRetainingCapacity();
        m.indices.clearRetainingCapacity();
        m.values.appendSlice(self.allocator, src.values.items) catch @panic("clap: OOM matching");
        m.indices.appendSlice(self.allocator, src.indices.items) catch @panic("clap: OOM matching");
        m.source = src.source;
        m.occurrences = src.occurrences;
    }

    // ----- retrieval -----

    /// Whether the argument was supplied explicitly — command line or env, but
    /// not a default (clap's `is_explicit`).
    pub fn isPresent(self: *const ArgMatches, id: []const u8) bool {
        const m = self.map.getPtr(id) orelse return false;
        return m.source != .default_value;
    }

    pub fn contains(self: *const ArgMatches, id: []const u8) bool {
        return self.map.contains(id);
    }

    /// Where the value for `id` came from, or null if absent.
    pub fn valueSource(self: *const ArgMatches, id: []const u8) ?ValueSource {
        const m = self.map.getPtr(id) orelse return null;
        return m.source;
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

    /// The parse-index of the first value of `id`, or null if absent (clap's `index_of`).
    pub fn indexOf(self: *const ArgMatches, id: []const u8) ?usize {
        const m = self.map.getPtr(id) orelse return null;
        if (m.indices.items.len == 0) return null;
        return m.indices.items[0];
    }

    /// All parse-indices of `id`'s values, or null if absent.
    pub fn indicesOf(self: *const ArgMatches, id: []const u8) ?[]const usize {
        const m = self.map.getPtr(id) orelse return null;
        if (m.indices.items.len == 0) return null;
        return m.indices.items;
    }

    /// Number of occurrences of a `Count`-action argument (0 if absent).
    pub fn getCount(self: *const ArgMatches, id: []const u8) usize {
        const m = self.map.getPtr(id) orelse return 0;
        return m.occurrences;
    }

    pub fn subcommand(self: *const ArgMatches) ?Subcommand {
        return self.sub;
    }

    /// Ids supplied on the command line (defaults excluded), for building
    /// contextual error usage. Order is unspecified (hash-map iteration).
    pub fn presentIds(self: *const ArgMatches, allocator: std.mem.Allocator) [][]const u8 {
        var ids: std.ArrayListUnmanaged([]const u8) = .empty;
        var it = self.map.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.source != .default_value) {
                ids.append(allocator, entry.key_ptr.*) catch @panic("clap: OOM");
            }
        }
        return ids.items;
    }

    /// Whether this command saw any command-line arg or subcommand (defaults
    /// don't count) — used by `arg_required_else_help`.
    pub fn suppliedAnything(self: *const ArgMatches) bool {
        if (self.sub != null) return true;
        var it = self.map.valueIterator();
        while (it.next()) |m| {
            if (m.source != .default_value) return true;
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
    m.pushValue("color", "never", 2);
    try testing.expectEqualStrings("never", m.getOne([]const u8, "color").?);
    try testing.expect(m.isPresent("color"));
    try testing.expect(m.getOne([]const u8, "missing") == null);
    try testing.expectEqual(@as(?usize, 2), m.indexOf("color"));

    m.pushValue("PATH", "a.txt", 3);
    m.pushValue("PATH", "b.txt", 4);
    const paths = m.getMany([]const u8, "PATH").?;
    try testing.expectEqual(@as(usize, 2), paths.len);
    try testing.expectEqualStrings("b.txt", paths[1]);
    try testing.expectEqualSlices(usize, &.{ 3, 4 }, m.indicesOf("PATH").?);
}

test "matches: defaults do not count as present" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const m = try ArgMatches.create(arena.allocator());

    m.setDefault("color", "auto", 1);
    try testing.expectEqualStrings("auto", m.getOne([]const u8, "color").?);
    try testing.expect(!m.isPresent("color"));
    try testing.expect(m.contains("color"));
}
