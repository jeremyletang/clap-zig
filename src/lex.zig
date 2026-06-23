const std = @import("std");

/// Lightweight lexer over the raw argv, modeled on clap's `clap_lex` crate:
/// https://github.com/clap-rs/clap/blob/master/clap_lex/src/lib.rs
/// Classifies a single token and provides a peekable cursor.
pub const Long = struct {
    /// flag name with the leading `--` stripped, up to the first `=`
    name: []const u8,
    /// inline value after `=`, if present (`--foo=bar` -> "bar"; `--foo=` -> "")
    value: ?[]const u8,
};

pub const ParsedArg = union(enum) {
    /// the `--` separator: everything after is positional
    escape,
    /// a bare `-` (conventionally stdin/stdout)
    stdio,
    long: Long,
    /// short cluster with the leading `-` stripped (`-abc` -> "abc", `-m=v` -> "m=v")
    short: []const u8,
    /// a plain value / positional
    value: []const u8,
};

pub fn classify(token: []const u8) ParsedArg {
    if (std.mem.eql(u8, token, "--")) return .escape;
    if (std.mem.eql(u8, token, "-")) return .stdio;
    if (std.mem.startsWith(u8, token, "--")) {
        const rest = token[2..];
        if (std.mem.indexOfScalar(u8, rest, '=')) |eq| {
            return .{ .long = .{ .name = rest[0..eq], .value = rest[eq + 1 ..] } };
        }
        return .{ .long = .{ .name = rest, .value = null } };
    }
    if (token.len > 1 and token[0] == '-') {
        return .{ .short = token[1..] };
    }
    return .{ .value = token };
}

/// A forward cursor over argv with single-token lookahead.
pub const Cursor = struct {
    args: []const []const u8,
    index: usize = 0,

    pub fn init(args: []const []const u8) Cursor {
        return .{ .args = args };
    }

    pub fn next(self: *Cursor) ?[]const u8 {
        if (self.index >= self.args.len) return null;
        const tok = self.args[self.index];
        self.index += 1;
        return tok;
    }

    pub fn peek(self: *const Cursor) ?[]const u8 {
        if (self.index >= self.args.len) return null;
        return self.args[self.index];
    }

    /// All tokens not yet consumed (including any already peeked but not `next`-ed).
    pub fn remaining(self: *const Cursor) []const []const u8 {
        return self.args[self.index..];
    }
};

const testing = std.testing;

test "classify: escape and stdio" {
    try testing.expectEqual(ParsedArg.escape, classify("--"));
    try testing.expectEqual(ParsedArg.stdio, classify("-"));
}

test "classify: long with and without value" {
    const a = classify("--color");
    try testing.expectEqualStrings("color", a.long.name);
    try testing.expect(a.long.value == null);

    const b = classify("--color=never");
    try testing.expectEqualStrings("color", b.long.name);
    try testing.expectEqualStrings("never", b.long.value.?);

    const c = classify("--color=");
    try testing.expectEqualStrings("color", c.long.name);
    try testing.expectEqualStrings("", c.long.value.?);
}

test "classify: short cluster and attached value" {
    try testing.expectEqualStrings("m", classify("-m").short);
    try testing.expectEqualStrings("abc", classify("-abc").short);
    try testing.expectEqualStrings("m=foo", classify("-m=foo").short);
}

test "classify: values" {
    try testing.expectEqualStrings("HEAD", classify("HEAD").value);
    try testing.expectEqualStrings("./src", classify("./src").value);
}

test "cursor: next, peek, remaining" {
    const argv = [_][]const u8{ "clone", "origin", "--bare" };
    var cur = Cursor.init(&argv);
    try testing.expectEqualStrings("clone", cur.peek().?);
    try testing.expectEqualStrings("clone", cur.next().?);
    try testing.expectEqualStrings("origin", cur.next().?);
    try testing.expectEqual(@as(usize, 1), cur.remaining().len);
    try testing.expectEqualStrings("--bare", cur.next().?);
    try testing.expect(cur.next() == null);
}
