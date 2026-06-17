const std = @import("std");

/// Behavior of an argument when it is encountered while parsing.
/// Port of clap's `ArgAction`:
/// https://github.com/clap-rs/clap/blob/master/clap_builder/src/builder/action.rs
pub const ArgAction = enum {
    set,
    append,
    set_true,
    set_false,
    count,
    help,
    help_short,
    help_long,
    version,

    /// Whether occurrences of this action consume a value from the command line.
    pub fn takesValue(self: ArgAction) bool {
        return switch (self) {
            .set, .append => true,
            .set_true, .set_false, .count, .help, .help_short, .help_long, .version => false,
        };
    }

    /// The implicit value stored for a no-value flag action (used by help rendering
    /// and `getOne`), or null for value-taking actions.
    pub fn defaultFlagValue(self: ArgAction) ?[]const u8 {
        return switch (self) {
            .set_true => "true",
            .set_false => "false",
            .count => "0",
            else => null,
        };
    }
};
