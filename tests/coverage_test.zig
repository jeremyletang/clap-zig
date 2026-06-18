const std = @import("std");
const universe = @import("clap_universe");
const coverage = @import("coverage");

const testing = std.testing;

// Every manifest entry must reference a real clap test, and none twice — guards
// against typos and against the universe being regenerated out from under us.
test "coverage manifest references real, unique clap tests" {
    for (coverage.entries, 0..) |e, i| {
        var found = false;
        for (universe.tests) |t| {
            if (std.mem.eql(u8, t.file, e.file) and std.mem.eql(u8, t.name, e.name)) {
                found = true;
                break;
            }
        }
        testing.expect(found) catch |err| {
            std.debug.print("manifest entry not in universe: {s}::{s}\n", .{ e.file, e.name });
            return err;
        };
        for (coverage.entries[i + 1 ..]) |o| {
            if (std.mem.eql(u8, o.file, e.file) and std.mem.eql(u8, o.name, e.name)) {
                std.debug.print("duplicate manifest entry: {s}::{s}\n", .{ e.file, e.name });
                return error.DuplicateEntry;
            }
        }
    }
}
