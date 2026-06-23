//! Shared glue for the example binaries' `main`: collect argv, run, print, exit.
//! Not part of the clap library — just keeps the example programs tidy.

const std = @import("std");
const clap = @import("clap");

/// In clap these come from the `command!()` macro reading package metadata; the
/// tutorial examples rely on them, so we supply matching constants for byte-exact output.
pub const pkg_about = "A simple to use, efficient, and full-featured Command Line Argument Parser";
pub const pkg_version = "4.5.40";

/// An optional value or a fallback when absent — for printing parsed results.
pub fn optOr(v: ?[]const u8, fallback: []const u8) []const u8 {
    return v orelse fallback;
}

/// Comma-join a list of values for display (`"(none)"` when empty/absent).
pub fn list(a: std.mem.Allocator, vals: ?[]const []const u8) []const u8 {
    const items = vals orelse return "(none)";
    if (items.len == 0) return "(none)";
    return std.mem.join(a, ", ", items) catch @panic("OOM");
}

/// Append a formatted line to an example's output buffer.
pub fn print(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) void {
    const s = std.fmt.allocPrint(allocator, fmt, args) catch @panic("OOM");
    out.appendSlice(allocator, s) catch @panic("OOM");
}

/// Collect argv, call `runFn` (which writes all output to a buffer and returns
/// an exit code), stream the buffer to stdout (code 0) or stderr (nonzero), exit.
pub fn execMain(
    init: std.process.Init,
    runFn: *const fn (std.mem.Allocator, []const []const u8, *std.ArrayList(u8)) u8,
) !void {
    const allocator = init.arena.allocator();
    const raw = try init.minimal.args.toSlice(allocator);
    var argv: std.ArrayList([]const u8) = .empty;
    for (raw) |arg_z| try argv.append(allocator, arg_z);

    // Resolve colour per cli_policies.txt for stdout and apply it for the whole
    // render (the examples' plain `clap.renderError`/`renderHelp` calls pick up
    // the active styles). Default ColorChoice is Auto.
    const env = init.environ_map;
    const is_tty = (std.Io.File.stdout().isTty(init.io)) catch false;
    var styles = clap.Styles.styled();
    if (clap.colorEnabled(.auto, env.get("NO_COLOR") != null, env.get("CLICOLOR_FORCE") != null, env.get("TERM"), is_tty)) {
        clap.setColorStyles(&styles);
    }
    defer clap.setColorStyles(null);

    var out: std.ArrayList(u8) = .empty;
    const code = runFn(allocator, argv.items[1..], &out);

    const file = if (code == 0) std.Io.File.stdout() else std.Io.File.stderr();
    try file.writeStreamingAll(init.io, out.items);
    std.process.exit(code);
}
