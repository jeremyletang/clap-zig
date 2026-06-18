const std = @import("std");

/// Outcome of validating one raw value with an `Arg`'s value parser: either it
/// is acceptable, or a reason string (shown after the colon in clap's
/// "invalid value '…' for '…': <reason>").
pub const ParseResult = union(enum) {
    ok,
    invalid: []const u8,
};

/// A value parser: validates a raw value, producing a reason on failure.
pub const ParserFn = *const fn (std.mem.Allocator, []const u8) ParseResult;

/// Build a parser for an integer type constrained to `[min, max]`, with
/// clap-compatible error messages.
pub fn rangedInt(comptime T: type, comptime min: T, comptime max: T) ParserFn {
    return &struct {
        fn parseRanged(a: std.mem.Allocator, s: []const u8) ParseResult {
            const n = std.fmt.parseInt(T, s, 10) catch
                return .{ .invalid = "invalid digit found in string" };
            if (n < min or n > max) {
                return .{ .invalid = std.fmt.allocPrint(a, "{d} is not in {d}..={d}", .{ n, min, max }) catch @panic("clap: OOM") };
            }
            return .ok;
        }
    }.parseRanged;
}

/// Typed parsing of a raw string value into `T`, used by `ArgMatches.getOne` /
/// `getMany`. Covers strings, ints, floats, bools, and enums.
pub const ParseError = error{InvalidValue};

pub fn parse(comptime T: type, s: []const u8) ParseError!T {
    if (T == []const u8) return s;
    return switch (@typeInfo(T)) {
        .int => std.fmt.parseInt(T, s, 10) catch error.InvalidValue,
        .float => std.fmt.parseFloat(T, s) catch error.InvalidValue,
        .bool => strToBool(s) orelse error.InvalidValue,
        .@"enum" => std.meta.stringToEnum(T, s) orelse error.InvalidValue,
        else => @compileError("unsupported value-parser type: " ++ @typeName(T)),
    };
}

fn strToBool(s: []const u8) ?bool {
    const true_set = [_][]const u8{ "true", "yes", "y", "1", "on" };
    const false_set = [_][]const u8{ "false", "no", "n", "0", "off" };
    for (true_set) |t| {
        if (std.ascii.eqlIgnoreCase(s, t)) return true;
    }
    for (false_set) |f| {
        if (std.ascii.eqlIgnoreCase(s, f)) return false;
    }
    return null;
}

const testing = std.testing;

test "parse: string passthrough" {
    try testing.expectEqualStrings("auto", try parse([]const u8, "auto"));
}

test "parse: int and bool and enum" {
    try testing.expectEqual(@as(u16, 42), try parse(u16, "42"));
    try testing.expectEqual(true, try parse(bool, "yes"));
    const Color = enum { always, auto, never };
    try testing.expectEqual(Color.never, try parse(Color, "never"));
    try testing.expectError(error.InvalidValue, parse(u8, "nope"));
}
