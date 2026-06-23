const std = @import("std");

/// A caller-supplied environment lookup for `Arg.env` fallbacks. The library
/// stays IO-free: the application provides the source (e.g. wrapping
/// `std.process.Init.environ_map`) and tests provide a fixed map. Mirrors how
/// clap reads `env::var_os`, but without the library touching the OS.
pub const EnvSource = struct {
    context: *const anyopaque,
    lookupFn: *const fn (*const anyopaque, []const u8) ?[]const u8,

    pub fn get(self: EnvSource, name: []const u8) ?[]const u8 {
        return self.lookupFn(self.context, name);
    }
};

/// Build an `EnvSource` backed by a `std.StringHashMap([]const u8)` (handy for
/// tests and for callers that already hold an env map).
pub fn mapSource(map: *const std.StringHashMap([]const u8)) EnvSource {
    return .{ .context = map, .lookupFn = mapLookup };
}

fn mapLookup(context: *const anyopaque, name: []const u8) ?[]const u8 {
    const map: *const std.StringHashMap([]const u8) = @ptrCast(@alignCast(context));
    return map.get(name);
}
