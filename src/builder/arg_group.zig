const std = @import("std");

/// A named relation over a set of arguments. Port of clap's `ArgGroup`:
/// https://github.com/clap-rs/clap/blob/master/clap_builder/src/builder/arg_group.rs
///
/// `required` means at least one member must be present; a non-`multiple` group
/// means its members are mutually exclusive (at most one).
pub const ArgGroup = struct {
    id: []const u8,
    member_ids: []const []const u8 = &.{},
    is_required: bool = false,
    is_multiple: bool = false,

    pub fn new(id: []const u8) ArgGroup {
        return .{ .id = id };
    }

    pub fn args(self: ArgGroup, ids: []const []const u8) ArgGroup {
        var g = self;
        g.member_ids = ids;
        return g;
    }

    pub fn required(self: ArgGroup, yes: bool) ArgGroup {
        var g = self;
        g.is_required = yes;
        return g;
    }

    pub fn multiple(self: ArgGroup, yes: bool) ArgGroup {
        var g = self;
        g.is_multiple = yes;
        return g;
    }
};
