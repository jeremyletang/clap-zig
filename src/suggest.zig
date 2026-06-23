//! "Did you mean" suggestions (clap's `suggestions` feature). Uses the Jaro
//! string-similarity metric with clap's `> 0.7` confidence threshold; candidates
//! are returned sorted by ascending similarity (most similar last), ties keeping
//! input order — matching clap's `did_you_mean`.

const std = @import("std");

/// Jaro similarity of two byte strings, in `[0, 1]`. Operates on bytes (ASCII);
/// clap operates on Unicode scalars, which agrees for ASCII inputs.
pub fn jaro(allocator: std.mem.Allocator, a: []const u8, b: []const u8) f64 {
    if (a.len == 0 and b.len == 0) return 1;
    if (a.len == 0 or b.len == 0) return 0;

    const window = (@max(a.len, b.len) / 2) -| 1;
    const a_match = allocator.alloc(bool, a.len) catch @panic("clap: OOM suggesting");
    defer allocator.free(a_match);
    const b_match = allocator.alloc(bool, b.len) catch @panic("clap: OOM suggesting");
    defer allocator.free(b_match);
    @memset(a_match, false);
    @memset(b_match, false);

    var matches: usize = 0;
    for (a, 0..) |ca, i| {
        const lo = if (i > window) i - window else 0;
        const hi = @min(i + window + 1, b.len);
        var j = lo;
        while (j < hi) : (j += 1) {
            if (!b_match[j] and b[j] == ca) {
                a_match[i] = true;
                b_match[j] = true;
                matches += 1;
                break;
            }
        }
    }
    if (matches == 0) return 0;

    // count transpositions: half the matched chars that are out of order
    var transpositions: usize = 0;
    var k: usize = 0;
    for (a, 0..) |ca, i| {
        if (!a_match[i]) continue;
        while (!b_match[k]) k += 1;
        if (ca != b[k]) transpositions += 1;
        k += 1;
    }
    const t = @as(f64, @floatFromInt(transpositions)) / 2.0;

    const m = @as(f64, @floatFromInt(matches));
    const la = @as(f64, @floatFromInt(a.len));
    const lb = @as(f64, @floatFromInt(b.len));
    return (m / la + m / lb + (m - t) / m) / 3.0;
}

/// Candidates from `possible` similar to `v`, ascending by similarity (most
/// similar last), ties keeping input order. Empty when nothing clears `0.7`.
pub fn didYouMean(allocator: std.mem.Allocator, v: []const u8, possible: []const []const u8) [][]const u8 {
    var scored: std.ArrayListUnmanaged(struct { c: f64, name: []const u8 }) = .empty;
    for (possible) |pv| {
        const confidence = jaro(allocator, v, pv);
        if (confidence <= 0.7) continue;
        // stable ascending insert: place after any equal-confidence entries
        var pos: usize = scored.items.len;
        for (scored.items, 0..) |e, i| {
            if (e.c > confidence) {
                pos = i;
                break;
            }
        }
        scored.insert(allocator, pos, .{ .c = confidence, .name = pv }) catch @panic("clap: OOM suggesting");
    }
    var out = allocator.alloc([]const u8, scored.items.len) catch @panic("clap: OOM suggesting");
    for (scored.items, 0..) |e, i| out[i] = e.name;
    return out;
}
