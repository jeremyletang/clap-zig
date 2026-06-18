//! Hand-maintained manifest of which clap builder tests we have addressed.
//! Each entry references a test in tests/clap_universe.zig:
//!   - `ported`   — translated and passing in a tests/clap_<file>_test.zig
//!   - `deferred` — needs a feature clap-zig hasn't implemented yet (see note)
//! Tests in the universe but absent here are still `pending`. Run
//! `zig build coverage` for the report. The goal is zero pending: every test is
//! either ported or deferred, i.e. 100% of what we support.

pub const Status = enum { ported, deferred };

pub const Entry = struct {
    file: []const u8,
    name: []const u8,
    status: Status,
    /// for `deferred`: the missing feature gating this test
    note: []const u8 = "",
};

pub const entries = [_]Entry{
    // ----- opts.rs -----
    .{ .file = "opts.rs", .name = "require_equals_fail", .status = .ported },
    .{ .file = "opts.rs", .name = "require_equals_fail_message", .status = .ported },
    .{ .file = "opts.rs", .name = "require_equals_pass", .status = .ported },
    .{ .file = "opts.rs", .name = "require_equals_empty_vals_pass", .status = .ported },
    .{ .file = "opts.rs", .name = "opts_using_short", .status = .ported },
    .{ .file = "opts.rs", .name = "opts_using_long_space", .status = .ported },
    .{ .file = "opts.rs", .name = "opts_using_long_equals", .status = .ported },
    .{ .file = "opts.rs", .name = "opts_using_mixed", .status = .ported },
    .{ .file = "opts.rs", .name = "opts_using_mixed2", .status = .ported },
    .{ .file = "opts.rs", .name = "default_values_user_value", .status = .ported },
    .{ .file = "opts.rs", .name = "stdin_char", .status = .ported },
    .{ .file = "opts.rs", .name = "multiple_vals_pos_arg_equals", .status = .ported },
    .{ .file = "opts.rs", .name = "double_hyphen_as_value", .status = .deferred, .note = "allow_hyphen_values" },
    .{ .file = "opts.rs", .name = "require_equals_no_empty_values_fail", .status = .deferred, .note = "NonEmptyStringValueParser" },
    .{ .file = "opts.rs", .name = "lots_o_vals", .status = .deferred, .note = "multi-value options (num_args>1)" },
    .{ .file = "opts.rs", .name = "require_delims_no_delim", .status = .deferred, .note = "value_delimiter" },
    .{ .file = "opts.rs", .name = "require_delims", .status = .deferred, .note = "value_delimiter" },
    .{ .file = "opts.rs", .name = "leading_hyphen_pass", .status = .deferred, .note = "allow_hyphen_values" },
};
