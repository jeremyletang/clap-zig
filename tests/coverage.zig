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

    // ----- flags.rs -----
    .{ .file = "flags.rs", .name = "flag_using_short", .status = .ported },
    .{ .file = "flags.rs", .name = "flag_using_long", .status = .ported },
    .{ .file = "flags.rs", .name = "flag_using_long_with_literals", .status = .ported },
    .{ .file = "flags.rs", .name = "flag_using_mixed", .status = .ported },
    .{ .file = "flags.rs", .name = "multiple_flags_in_single", .status = .ported },
    .{ .file = "flags.rs", .name = "unexpected_value_error", .status = .ported },
    .{ .file = "flags.rs", .name = "lots_o_flags_sep", .status = .deferred, .note = "args_override_self" },
    .{ .file = "flags.rs", .name = "lots_o_flags_combined", .status = .deferred, .note = "args_override_self" },
    .{ .file = "flags.rs", .name = "issue_1284_argument_in_flag_style", .status = .deferred, .note = "error trailing-arg tip" },
    .{ .file = "flags.rs", .name = "issue_2308_multiple_dashes", .status = .deferred, .note = "error trailing-arg tip" },
    .{ .file = "flags.rs", .name = "leading_dash_stripped", .status = .deferred, .note = "debug_assert" },
    .{ .file = "flags.rs", .name = "optional_value", .status = .deferred, .note = "optional-value SetTrue (num_args 0..=1)" },

    // ----- positionals.rs -----
    .{ .file = "positionals.rs", .name = "only_pos_follow", .status = .ported },
    .{ .file = "positionals.rs", .name = "positional", .status = .ported },
    .{ .file = "positionals.rs", .name = "lots_o_vals", .status = .ported },
    .{ .file = "positionals.rs", .name = "positional_multiple", .status = .ported },
    .{ .file = "positionals.rs", .name = "positional_multiple_3", .status = .ported },
    .{ .file = "positionals.rs", .name = "positional_multiple_2", .status = .ported },
    .{ .file = "positionals.rs", .name = "positional_possible_values", .status = .ported },
    .{ .file = "positionals.rs", .name = "create_positional", .status = .ported },
    .{ .file = "positionals.rs", .name = "positional_hyphen_does_not_panic", .status = .ported },
    .{ .file = "positionals.rs", .name = "single_positional_usage_string", .status = .ported },
    .{ .file = "positionals.rs", .name = "single_positional_multiple_usage_string", .status = .ported },
    .{ .file = "positionals.rs", .name = "multiple_positional_usage_string", .status = .ported },
    .{ .file = "positionals.rs", .name = "multiple_positional_one_required_usage_string", .status = .ported },
    .{ .file = "positionals.rs", .name = "single_positional_required_usage_string", .status = .ported },
    .{ .file = "positionals.rs", .name = "missing_required_2", .status = .ported },
    .{ .file = "positionals.rs", .name = "last_positional", .status = .ported },
    .{ .file = "positionals.rs", .name = "last_positional_no_double_dash", .status = .ported },
    .{ .file = "positionals.rs", .name = "last_positional_second_to_last_mult", .status = .ported },
    .{ .file = "positionals.rs", .name = "issue_946", .status = .deferred, .note = "allow_hyphen_values" },
    .{ .file = "positionals.rs", .name = "missing_required", .status = .deferred, .note = "debug_assert" },
    .{ .file = "positionals.rs", .name = "positional_arg_with_long", .status = .deferred, .note = "debug_assert" },
    .{ .file = "positionals.rs", .name = "positional_arg_with_short", .status = .deferred, .note = "debug_assert" },
    .{ .file = "positionals.rs", .name = "ignore_hyphen_values_on_last", .status = .deferred, .note = "allow_hyphen_values" },
};
