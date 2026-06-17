const std = @import("std");
const action = @import("action.zig");

/// Inclusive number-of-values range for an argument (`num_args`).
/// Port of clap's `ValueRange`:
/// https://github.com/clap-rs/clap/blob/master/clap_builder/src/builder/range.rs
pub const ValueRange = struct {
    min: usize,
    max: usize,

    /// Sentinel for an unbounded upper end (e.g. `1..`).
    pub const unbounded = std.math.maxInt(usize);

    pub const single = ValueRange{ .min = 1, .max = 1 };

    pub fn between(min: usize, max: usize) ValueRange {
        std.debug.assert(min <= max);
        return .{ .min = min, .max = max };
    }

    /// `n..` — at least `min`, no upper bound.
    pub fn atLeast(min: usize) ValueRange {
        return .{ .min = min, .max = unbounded };
    }

    /// The default range implied by an action when `num_args` is unset.
    pub fn forAction(a: action.ArgAction) ValueRange {
        return if (a.takesValue()) single else .{ .min = 0, .max = 0 };
    }

    pub fn takesValues(self: ValueRange) bool {
        return self.max > 0;
    }

    pub fn isMultiple(self: ValueRange) bool {
        return self.max > 1;
    }

    pub fn contains(self: ValueRange, n: usize) bool {
        return n >= self.min and n <= self.max;
    }
};
