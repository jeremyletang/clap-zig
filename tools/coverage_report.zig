//! `zig build coverage` — report clap-test coverage from the generated universe
//! (tests/clap_universe.zig) and our manifest (tests/coverage.zig). Prints
//! ported/deferred/pending counts, the "% of supported" figure, and the pending
//! work queue per file. Exits non-zero if the manifest references an unknown
//! test (e.g. after the universe was regenerated and a test was renamed).

const std = @import("std");
const universe = @import("clap_universe");
const coverage = @import("coverage");

pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    var out: std.ArrayList(u8) = .empty;

    var unknown: usize = 0;
    for (coverage.entries) |e| {
        if (!inUniverse(e.file, e.name)) {
            print(a, &out, "warning: manifest entry not in universe: {s}::{s}\n", .{ e.file, e.name });
            unknown += 1;
        }
    }

    var ported: usize = 0;
    var deferred: usize = 0;
    for (coverage.entries) |e| switch (e.status) {
        .ported => ported += 1,
        .deferred => deferred += 1,
    };

    const total = universe.tests.len;
    const supported = total - deferred;
    const pending = total - ported - deferred;
    const pct = if (supported == 0) 0.0 else @as(f64, @floatFromInt(ported)) * 100.0 / @as(f64, @floatFromInt(supported));

    print(a, &out, "clap builder test coverage\n", .{});
    print(a, &out, "  total:     {d}\n", .{total});
    print(a, &out, "  ported:    {d}\n", .{ported});
    print(a, &out, "  deferred:  {d}\n", .{deferred});
    print(a, &out, "  pending:   {d}\n", .{pending});
    print(a, &out, "  supported: {d}  (total - deferred)\n", .{supported});
    print(a, &out, "  covered:   {d:.1}%  (ported / supported)\n", .{pct});

    appendDeferred(a, &out);
    appendPendingByFile(a, &out);

    try std.Io.File.stdout().writeStreamingAll(init.io, out.items);
    if (unknown != 0) std.process.exit(1);
}

fn appendDeferred(a: std.mem.Allocator, out: *std.ArrayList(u8)) void {
    if (coverage.entries.len == 0) return;
    var any = false;
    for (coverage.entries) |e| {
        if (e.status != .deferred) continue;
        if (!any) {
            print(a, out, "\nDeferred (needs feature):\n", .{});
            any = true;
        }
        print(a, out, "  {s}::{s}  [{s}]\n", .{ e.file, e.name, e.note });
    }
}

fn appendPendingByFile(a: std.mem.Allocator, out: *std.ArrayList(u8)) void {
    print(a, out, "\nPending by file:\n", .{});
    var seen: std.ArrayListUnmanaged([]const u8) = .empty;
    for (universe.tests) |t| {
        if (addressed(t.file, t.name)) continue;
        if (contains(seen.items, t.file)) continue;
        seen.append(a, t.file) catch @panic("OOM");
        var count: usize = 0;
        for (universe.tests) |u| {
            if (std.mem.eql(u8, u.file, t.file) and !addressed(u.file, u.name)) count += 1;
        }
        print(a, out, "  {s: <26} {d}\n", .{ t.file, count });
    }
}

fn inUniverse(file: []const u8, name: []const u8) bool {
    for (universe.tests) |t| {
        if (std.mem.eql(u8, t.file, file) and std.mem.eql(u8, t.name, name)) return true;
    }
    return false;
}

fn addressed(file: []const u8, name: []const u8) bool {
    for (coverage.entries) |e| {
        if (std.mem.eql(u8, e.file, file) and std.mem.eql(u8, e.name, name)) return true;
    }
    return false;
}

fn contains(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |h| {
        if (std.mem.eql(u8, h, needle)) return true;
    }
    return false;
}

fn print(a: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) void {
    const s = std.fmt.allocPrint(a, fmt, args) catch @panic("OOM");
    out.appendSlice(a, s) catch @panic("OOM");
}
