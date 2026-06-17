const std = @import("std");

// public surface (filled in as modules land)
pub const version = "0.0.0";

test {
    std.testing.refAllDecls(@This());
}
