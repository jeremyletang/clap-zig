const std = @import("std");
const command = @import("builder/command.zig");

/// Classification of a parsing/validation failure or a help/version request.
/// Port of clap's `ErrorKind` (subset for now):
/// https://github.com/clap-rs/clap/blob/master/clap_builder/src/error/kind.rs
pub const ErrorKind = enum {
    /// `--help` / `-h` / the `help` subcommand was requested (exit 0).
    display_help,
    /// `--version` / `-V` was requested (exit 0).
    display_version,
    /// help shown because nothing was supplied and `arg_required_else_help` is set (exit 2).
    display_help_on_missing_argument_or_subcommand,
    invalid_value,
    wrong_number_of_values,
    too_few_values,
    unknown_argument,
    invalid_subcommand,
    no_equals,
    too_many_values,
    missing_required_argument,
    missing_subcommand,
    argument_conflict,

    /// Whether this kind is a successful help/version display (exit 0) vs an error (exit 2).
    pub fn isSuccess(self: ErrorKind) bool {
        return self == .display_help or self == .display_version;
    }

    pub fn exitCode(self: ErrorKind) u8 {
        return if (self.isSuccess()) 0 else 2;
    }
};

/// A parsing error or a help request. Carries enough context for the renderer
/// (`output/error.zig`, milestone-1 task #6) to produce clap-style output.
pub const Error = struct {
    kind: ErrorKind,
    /// the command the error occurred in (for usage/help rendering)
    cmd: *const command.Command,
    /// the offending argument's display string, when relevant
    arg: ?[]const u8 = null,
    /// the offending value, when relevant
    value: ?[]const u8 = null,
    /// allowed values, for `invalid_value`
    possible_values: ?[]const []const u8 = null,
    /// failure reason shown after the colon, for `invalid_value` from a value parser
    reason: ?[]const u8 = null,
    /// ids (present + missing-required) for contextual "smart" usage; when null,
    /// the renderer uses the help-style usage (with `[OPTIONS]`)
    used_ids: ?[]const []const u8 = null,
    /// for `display_help`: whether `--help` (long) vs `-h` (short) was requested
    help_long: bool = false,
    /// for `argument_conflict`: the "cannot be used multiple times" variant
    multiple_use: bool = false,
    /// for `argument_conflict`: the other args this one conflicts with (display strings)
    conflicts: ?[]const []const u8 = null,
    /// for `invalid_value`: the "a value is required ... but none was supplied" variant
    value_required: bool = false,
    /// for `wrong_number_of_values` / `too_few_values`: expected vs provided counts
    n_expected: usize = 0,
    n_provided: usize = 0,
};
