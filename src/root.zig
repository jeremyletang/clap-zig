const std = @import("std");
const action = @import("builder/action.zig");
const arg = @import("builder/arg.zig");
const range = @import("builder/range.zig");
const command = @import("builder/command.zig");
const arg_group = @import("builder/arg_group.zig");
const value_parser = @import("builder/value_parser.zig");
const lex = @import("lex.zig");
const matcher = @import("parser/matcher.zig");
const parser = @import("parser/parser.zig");
const err = @import("error.zig");
const help = @import("output/help.zig");
const usage = @import("output/usage.zig");
const style = @import("output/style.zig");

pub const ArgAction = action.ArgAction;
pub const Arg = arg.Arg;
pub const RequireIf = arg.RequireIf;
pub const ValueRange = range.ValueRange;
pub const ParseResult = value_parser.ParseResult;
pub const ParserFn = value_parser.ParserFn;
pub const rangedInt = value_parser.rangedInt;
pub const Command = command.Command;
pub const ArgGroup = arg_group.ArgGroup;
pub const PossibleValue = @import("builder/possible_value.zig").PossibleValue;
pub const ArgMatches = matcher.ArgMatches;
pub const Subcommand = matcher.Subcommand;
pub const ValueSource = matcher.ValueSource;
pub const ErrorKind = err.ErrorKind;
pub const Error = err.Error;
pub const Outcome = parser.Outcome;
pub const parse = parser.parse;
pub const getMatches = parser.getMatches;
pub const external_id = parser.external_id;
/// Render a command's compact (`-h`) help text (plain, no colour).
pub fn renderHelp(allocator: std.mem.Allocator, cmd: *const Command) []const u8 {
    return help.render(allocator, cmd, false);
}
pub const renderUsage = usage.render;
pub const renderError = @import("output/error.zig").render;

// ----- colour / styling -----
pub const ColorChoice = style.ColorChoice;
pub const Styles = style.Styles;
/// Apply `cli_policies.txt` to decide whether to emit ANSI (caller supplies env/tty).
pub const colorEnabled = style.enabled;
/// Set the render-scoped active styles (null = plain) for plain `renderHelp`/
/// `renderError` calls — used to colour output at the IO boundary. Reset to null
/// when done.
pub const setColorStyles = style.setActive;

/// Render `-h` help with the given styles applied for the duration of the call.
pub fn renderHelpStyled(allocator: std.mem.Allocator, cmd: *const Command, styles: *const Styles, long: bool) []const u8 {
    style.setActive(styles);
    defer style.setActive(null);
    return help.render(allocator, cmd, long);
}

/// Render an outcome's error/help/version with the given styles applied.
pub fn renderErrorStyled(allocator: std.mem.Allocator, e: Error, styles: *const Styles) []const u8 {
    style.setActive(styles);
    defer style.setActive(null);
    return renderError(allocator, e);
}

pub const version = "0.0.0";

test {
    std.testing.refAllDecls(@This());
    _ = action;
    _ = arg;
    _ = range;
    _ = command;
    _ = arg_group;
    _ = value_parser;
    _ = lex;
    _ = matcher;
    _ = parser;
    _ = err;
    _ = help;
    _ = usage;
}
