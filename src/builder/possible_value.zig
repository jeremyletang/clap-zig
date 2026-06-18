/// One accepted value of an argument, optionally with its own help text (shown
/// in long help). Port of clap's `PossibleValue`:
/// https://github.com/clap-rs/clap/blob/master/clap_builder/src/builder/possible_value.rs
pub const PossibleValue = struct {
    name: []const u8,
    help: ?[]const u8 = null,
};
