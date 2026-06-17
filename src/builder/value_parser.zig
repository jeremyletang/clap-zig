const std = @import("std");

/// Typed parsing of a raw string value into `T`, used by `ArgMatches.getOne` /
/// `getMany`. Milestone 1 covers strings, ints, bools, and enums; the richer
/// parser set (ranged ints, custom parsers) lands in a later milestone.
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
