const std = @import("std");
const arg = @import("arg.zig");
const arg_group = @import("arg_group.zig");
const style = @import("../output/style.zig");

const Arg = arg.Arg;
const ArgGroup = arg_group.ArgGroup;

/// A command (or subcommand): a name, settings, its arguments, and nested
/// subcommands. Port of clap's `Command`:
/// https://github.com/clap-rs/clap/blob/master/clap_builder/src/builder/command.rs
///
/// Arena-backed builder: `init` stores the allocator, setters chain by value,
/// and append-style methods (`arg`, `args`, `subcommand`) mutate in place.
/// Building is expected at startup, so allocation failure panics rather than
/// threading an error through the fluent chain.
pub const Command = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    bin_name: ?[]const u8 = null,
    aliases_list: ?[]const []const u8 = null,
    visible_aliases_list: ?[]const []const u8 = null,
    // flag subcommands (clap's `short_flag`/`long_flag` + their aliases)
    short_flag: ?u8 = null,
    long_flag: ?[]const u8 = null,
    short_flag_aliases_list: ?[]const u8 = null,
    visible_short_flag_aliases_list: ?[]const u8 = null,
    long_flag_aliases_list: ?[]const []const u8 = null,
    visible_long_flag_aliases_list: ?[]const []const u8 = null,
    is_hidden: bool = false,
    /// this command's sort order as a subcommand (clap's `display_order`)
    disp_ord: ?usize = null,
    /// counter auto-assigned to children's display order; null disables it
    /// (clap's `next_display_order`)
    current_disp_ord: ?usize = 0,
    about_text: ?[]const u8 = null,
    version_str: ?[]const u8 = null,
    long_version_str: ?[]const u8 = null,
    /// propagate `version`/`long_version` to subcommands (clap's `propagate_version`)
    propagate_version: bool = false,
    author_text: ?[]const u8 = null,
    help_template_text: ?[]const u8 = null,
    usage_override: ?[]const u8 = null,
    /// placeholder for the subcommand slot in usage (clap's `subcommand_value_name`,
    /// default `COMMAND`)
    subcommand_value_name: ?[]const u8 = null,
    /// heading for the subcommands help section (clap's `subcommand_help_heading`,
    /// default `Commands`)
    subcommand_help_heading: ?[]const u8 = null,
    /// when set (>0), help text wraps to this column count (clap's `term_width`)
    term_width: ?usize = null,
    color_choice: style.ColorChoice = .auto,
    /// the heading stamped onto subsequently-added args (clap's `next_help_heading`)
    current_help_heading: ?[]const u8 = null,
    before_help_text: ?[]const u8 = null,
    after_help_text: ?[]const u8 = null,
    before_long_help_text: ?[]const u8 = null,
    after_long_help_text: ?[]const u8 = null,
    long_about_text: ?[]const u8 = null,
    arg_list: std.ArrayListUnmanaged(Arg) = .empty,
    subcommands: std.ArrayListUnmanaged(Command) = .empty,
    groups: std.ArrayListUnmanaged(ArgGroup) = .empty,

    subcommand_required: bool = false,
    arg_required_else_help: bool = false,
    allow_external_subcommands: bool = false,
    args_conflicts_with_subcommands: bool = false,
    /// a present subcommand waives the parent's required args (clap's `subcommand_negates_reqs`)
    subcommand_negates_reqs: bool = false,
    flatten_help: bool = false,
    /// force every arg/subcommand to render its help on the next line (clap's `next_line_help`)
    next_line_help: bool = false,
    disable_help_flag: bool = false,
    disable_help_subcommand: bool = false,
    disable_version_flag: bool = false,
    args_override_self: bool = false,
    /// swallow recoverable parse errors and return best-effort matches (clap's `ignore_errors`)
    ignore_errors: bool = false,
    /// dispatch on the first argument as an applet name (clap's `multicall`):
    /// subcommands are rooted at their own name and the root usage is just `<COMMAND>`
    is_multicall: bool = false,
    /// resolve an unambiguous subcommand prefix to its full name (clap's `infer_subcommands`)
    infer_subcommands: bool = false,
    /// resolve an unambiguous `--long` prefix to its full flag (clap's `infer_long_args`)
    infer_long_args: bool = false,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) Command {
        return .{ .allocator = allocator, .name = name };
    }

    pub fn deinit(self: *Command) void {
        for (self.subcommands.items) |*sc| sc.deinit();
        self.subcommands.deinit(self.allocator);
        self.arg_list.deinit(self.allocator);
        self.groups.deinit(self.allocator);
    }

    // ----- builder setters -----

    pub fn about(self: Command, text: []const u8) Command {
        var c = self;
        c.about_text = text;
        return c;
    }

    /// Hidden names this subcommand also responds to (clap's `alias`/`aliases`).
    pub fn aliases(self: Command, names: []const []const u8) Command {
        var c = self;
        c.aliases_list = names;
        return c;
    }

    /// Names this subcommand responds to and that are shown in help (clap's
    /// `visible_alias`/`visible_aliases`).
    pub fn visibleAliases(self: Command, names: []const []const u8) Command {
        var c = self;
        c.visible_aliases_list = names;
        return c;
    }

    /// Invoke this subcommand via `-X` (clap's `short_flag`).
    pub fn shortFlag(self: Command, c: u8) Command {
        var s = self;
        s.short_flag = c;
        return s;
    }

    /// Invoke this subcommand via `--name` (clap's `long_flag`).
    pub fn longFlag(self: Command, name: []const u8) Command {
        var s = self;
        s.long_flag = name;
        return s;
    }

    /// Hidden short-flag aliases (clap's `short_flag_alias(es)`).
    pub fn shortFlagAliases(self: Command, chars: []const u8) Command {
        var s = self;
        s.short_flag_aliases_list = chars;
        return s;
    }

    /// Short-flag aliases shown in help (clap's `visible_short_flag_alias(es)`).
    pub fn visibleShortFlagAliases(self: Command, chars: []const u8) Command {
        var s = self;
        s.visible_short_flag_aliases_list = chars;
        return s;
    }

    /// Hidden long-flag aliases (clap's `long_flag_alias(es)`).
    pub fn longFlagAliases(self: Command, names: []const []const u8) Command {
        var s = self;
        s.long_flag_aliases_list = names;
        return s;
    }

    /// Long-flag aliases shown in help (clap's `visible_long_flag_alias(es)`).
    pub fn visibleLongFlagAliases(self: Command, names: []const []const u8) Command {
        var s = self;
        s.visible_long_flag_aliases_list = names;
        return s;
    }

    /// Longer "about" shown only in `--help` (clap's `long_about`).
    pub fn longAbout(self: Command, text: []const u8) Command {
        var c = self;
        c.long_about_text = text;
        return c;
    }

    /// Free text printed before everything else in the help output.
    pub fn beforeHelp(self: Command, text: []const u8) Command {
        var c = self;
        c.before_help_text = text;
        return c;
    }

    /// Free text printed after everything else in the help output.
    pub fn afterHelp(self: Command, text: []const u8) Command {
        var c = self;
        c.after_help_text = text;
        return c;
    }

    /// `before_help` override used only in `--help` (long) output.
    pub fn beforeLongHelp(self: Command, text: []const u8) Command {
        var c = self;
        c.before_long_help_text = text;
        return c;
    }

    /// `after_help` override used only in `--help` (long) output.
    pub fn afterLongHelp(self: Command, text: []const u8) Command {
        var c = self;
        c.after_long_help_text = text;
        return c;
    }

    pub fn version(self: Command, v: []const u8) Command {
        var c = self;
        c.version_str = v;
        return c;
    }

    /// Rename the subcommand placeholder in usage (clap's `subcommand_value_name`).
    pub fn subcommandValueName(self: Command, name: []const u8) Command {
        var c = self;
        c.subcommand_value_name = name;
        return c;
    }

    /// Rename the subcommands help section heading (clap's `subcommand_help_heading`).
    pub fn subcommandHelpHeading(self: Command, heading: []const u8) Command {
        var c = self;
        c.subcommand_help_heading = heading;
        return c;
    }

    /// A longer version string, shown for `--version` (clap's `long_version`).
    /// `-V` keeps using `version`; if only one is set, both flags use it.
    pub fn longVersion(self: Command, v: []const u8) Command {
        var c = self;
        c.long_version_str = v;
        return c;
    }

    /// Propagate `version`/`long_version` to subcommands (clap's `propagate_version`).
    pub fn propagateVersion(self: Command, yes: bool) Command {
        var c = self;
        c.propagate_version = yes;
        return c;
    }

    /// Stored for parity; not yet shown in help output.
    pub fn author(self: Command, a: []const u8) Command {
        var c = self;
        c.author_text = a;
        return c;
    }

    /// Custom help layout via `{tag}` substitution (clap's `help_template`).
    pub fn helpTemplate(self: Command, t: []const u8) Command {
        var c = self;
        c.help_template_text = t;
        return c;
    }

    /// Replace the auto-generated usage body with a fixed string (clap's
    /// `override_usage`); used by `{usage}` and the `Usage:` line.
    pub fn overrideUsage(self: Command, t: []const u8) Command {
        var c = self;
        c.usage_override = t;
        return c;
    }

    /// Wrap help text to `n` columns (clap's `term_width`); 0 disables wrapping.
    pub fn termWidth(self: Command, n: usize) Command {
        var c = self;
        c.term_width = n;
        return c;
    }

    /// When to emit ANSI styling (clap's `color`); propagates to subcommands.
    pub fn color(self: Command, choice: style.ColorChoice) Command {
        var c = self;
        c.color_choice = choice;
        return c;
    }

    pub fn getColor(self: *const Command) style.ColorChoice {
        return self.color_choice;
    }

    /// The about text for help: the long about in `--help` (if set), else the
    /// regular about.
    pub fn aboutText(self: *const Command, long: bool) ?[]const u8 {
        if (long) return self.long_about_text orelse self.about_text;
        return self.about_text;
    }

    /// Whether the auto `-V/--version` flag applies (version set and not disabled).
    pub fn hasVersionFlag(self: *const Command) bool {
        return (self.version_str != null or self.long_version_str != null) and !self.disable_version_flag;
    }

    pub fn binName(self: Command, name: []const u8) Command {
        var c = self;
        c.bin_name = name;
        return c;
    }

    pub fn arg(self: Command, a: Arg) Command {
        var c = self;
        var to_add = a;
        if (to_add.isPositional() and to_add.index == null) {
            to_add.index = c.countPositionals() + 1;
        }
        // args inherit the command's current help heading unless they set one
        if (!to_add.help_heading_set) to_add.help_heading = c.current_help_heading;
        // auto-assign display order in definition order (clap's next_display_order)
        if (c.current_disp_ord) |cur| {
            if (to_add.disp_ord == null) to_add.disp_ord = cur;
            c.current_disp_ord = cur + 1;
        }
        c.arg_list.append(c.allocator, to_add) catch @panic("clap: OOM building command");
        return c;
    }

    /// Set the display order assigned to args/subcommands added after this call;
    /// null stops auto-assignment so they sort alphabetically (clap's
    /// `next_display_order`).
    pub fn nextDisplayOrder(self: Command, n: ?usize) Command {
        var c = self;
        c.current_disp_ord = n;
        return c;
    }

    /// This command's sort position in its parent's `Commands:` list.
    pub fn displayOrder(self: Command, n: usize) Command {
        var c = self;
        c.disp_ord = n;
        return c;
    }

    /// Set the help-section heading applied to args added after this call
    /// (clap's `next_help_heading`); null returns to the default `Options:`.
    pub fn nextHelpHeading(self: Command, heading: ?[]const u8) Command {
        var c = self;
        c.current_help_heading = heading;
        return c;
    }

    pub fn args(self: Command, list: []const Arg) Command {
        var c = self;
        for (list) |a| c = c.arg(a);
        return c;
    }

    pub fn subcommand(self: Command, cmd: Command) Command {
        var c = self;
        var to_add = cmd;
        if (c.current_disp_ord) |cur| {
            if (to_add.disp_ord == null) to_add.disp_ord = cur;
            c.current_disp_ord = cur + 1;
        }
        c.subcommands.append(c.allocator, to_add) catch @panic("clap: OOM building command");
        return c;
    }

    /// Display order of this command's children's synthetic help/version entries,
    /// i.e. the counter after all real args/subcommands (999 if disabled).
    pub fn builtinOrder(self: *const Command) usize {
        return self.current_disp_ord orelse 999;
    }

    pub fn group(self: Command, g: ArgGroup) Command {
        var c = self;
        c.groups.append(c.allocator, g) catch @panic("clap: OOM building command");
        return c;
    }

    pub fn subcommandRequired(self: Command, yes: bool) Command {
        var c = self;
        c.subcommand_required = yes;
        return c;
    }

    pub fn argRequiredElseHelp(self: Command, yes: bool) Command {
        var c = self;
        c.arg_required_else_help = yes;
        return c;
    }

    pub fn allowExternalSubcommands(self: Command, yes: bool) Command {
        var c = self;
        c.allow_external_subcommands = yes;
        return c;
    }

    /// A present subcommand waives the parent's required args (clap's `subcommand_negates_reqs`).
    pub fn subcommandNegatesReqs(self: Command, yes: bool) Command {
        var c = self;
        c.subcommand_negates_reqs = yes;
        return c;
    }

    pub fn argsConflictsWithSubcommands(self: Command, yes: bool) Command {
        var c = self;
        c.args_conflicts_with_subcommands = yes;
        return c;
    }

    pub fn flattenHelp(self: Command, yes: bool) Command {
        var c = self;
        c.flatten_help = yes;
        return c;
    }

    /// Force every arg/subcommand's help onto the next line (clap's `next_line_help`).
    pub fn nextLineHelp(self: Command, yes: bool) Command {
        var c = self;
        c.next_line_help = yes;
        return c;
    }

    /// Allow a non-multiple arg to be given more than once, keeping the last
    /// (clap's `args_override_self`); otherwise a repeat is an error.
    pub fn argsOverrideSelf(self: Command, yes: bool) Command {
        var c = self;
        c.args_override_self = yes;
        return c;
    }

    /// Dispatch on the first argument as an applet name, BusyBox-style (clap's
    /// `multicall`). Each subcommand becomes a top-level applet (its `bin_name` is
    /// its own name) and the root's usage is just the subcommand placeholder.
    pub fn multicall(self: Command, yes: bool) Command {
        var c = self;
        c.is_multicall = yes;
        return c;
    }

    /// Swallow recoverable parse errors and return best-effort matches; help and
    /// version requests still display (clap's `ignore_errors`).
    pub fn ignoreErrors(self: Command, yes: bool) Command {
        var c = self;
        c.ignore_errors = yes;
        return c;
    }

    /// Resolve an unambiguous subcommand-name prefix to the full subcommand
    /// (clap's `infer_subcommands`).
    pub fn inferSubcommands(self: Command, yes: bool) Command {
        var c = self;
        c.infer_subcommands = yes;
        return c;
    }

    /// Resolve an unambiguous `--long` prefix to the full flag (clap's
    /// `infer_long_args`).
    pub fn inferLongArgs(self: Command, yes: bool) Command {
        var c = self;
        c.infer_long_args = yes;
        return c;
    }

    /// Suppress the automatic `-h/--help` flag (clap's `disable_help_flag`).
    pub fn disableHelpFlag(self: Command, yes: bool) Command {
        var c = self;
        c.disable_help_flag = yes;
        return c;
    }

    /// Suppress the automatic `help` subcommand (clap's `disable_help_subcommand`).
    pub fn disableHelpSubcommand(self: Command, yes: bool) Command {
        var c = self;
        c.disable_help_subcommand = yes;
        return c;
    }

    /// Suppress the automatic `-V/--version` flag (clap's `disable_version_flag`).
    pub fn disableVersionFlag(self: Command, yes: bool) Command {
        var c = self;
        c.disable_version_flag = yes;
        return c;
    }

    /// Propagate full binary-name paths down the tree (clap's `_build`):
    /// a subcommand's `bin_name` becomes "<parent path> <name>". Call once on the
    /// root before parsing/help so usage lines read e.g. "git stash push".
    pub fn buildTree(self: *Command) void {
        self.propagate(self.bin_name orelse self.name, &.{});
    }

    /// Propagate bin-name paths and inherited global args down the tree: a
    /// subcommand inherits every ancestor's `global` arg so its parser
    /// recognizes them (clap's global propagation).
    fn propagate(self: *Command, path: []const u8, inherited_globals: []const Arg) void {
        self.bin_name = path;
        for (inherited_globals) |g| {
            if (self.findArgById(g.id) == null) {
                self.arg_list.append(self.allocator, g) catch @panic("clap: OOM building command");
            }
        }
        var globals: std.ArrayListUnmanaged(Arg) = .empty;
        for (self.arg_list.items) |*a| {
            if (a.is_global) globals.append(self.allocator, a.*) catch @panic("clap: OOM building command");
        }
        for (self.subcommands.items) |*sc| {
            sc.color_choice = self.color_choice; // color is global (clap)
            if (self.ignore_errors) sc.ignore_errors = true; // propagated to subcommands
            if (self.propagate_version) {
                sc.propagate_version = true;
                if (sc.version_str == null) sc.version_str = self.version_str;
                if (sc.long_version_str == null) sc.long_version_str = self.long_version_str;
            }
            // a multicall command's subcommands are top-level applets: their path
            // starts at their own name, not "<root> <name>"
            const child = if (self.is_multicall)
                sc.name
            else
                std.fmt.allocPrint(self.allocator, "{s} {s}", .{ path, sc.name }) catch
                    @panic("clap: OOM building command");
            sc.propagate(child, globals.items);
        }
    }

    // ----- queries -----

    pub fn displayName(self: *const Command) []const u8 {
        return self.bin_name orelse self.name;
    }

    pub fn countPositionals(self: *const Command) usize {
        var n: usize = 0;
        for (self.arg_list.items) |*a| {
            if (a.isPositional()) n += 1;
        }
        return n;
    }

    pub fn hasSubcommands(self: *const Command) bool {
        return self.subcommands.items.len > 0;
    }

    /// Hide this subcommand from help output and usage (clap's `hide`).
    pub fn hide(self: Command, yes: bool) Command {
        var c = self;
        c.is_hidden = yes;
        return c;
    }

    /// Whether any subcommand is shown in help (not hidden) — gates the
    /// `Commands:` section, the auto `help` entry, and `[COMMAND]` in usage.
    pub fn hasVisibleSubcommands(self: *const Command) bool {
        for (self.subcommands.items) |*sc| {
            if (!sc.is_hidden) return true;
        }
        return false;
    }

    pub fn findArgByLong(self: *const Command, name: []const u8) ?*const Arg {
        for (self.arg_list.items) |*a| {
            if (a.matchesLong(name)) return a;
        }
        return null;
    }

    pub const ArgInfer = union(enum) { none, ambiguous, unique: *const Arg };

    /// Ambiguity-aware prefix lookup over long names + aliases (infer_long_args).
    /// An exact match is the caller's job (`findArgByLong`); this handles prefixes.
    pub fn inferArgByLong(self: *const Command, prefix: []const u8) ArgInfer {
        var found: ?*const Arg = null;
        for (self.arg_list.items) |*a| {
            if (a.anyLongStartsWith(prefix)) {
                if (found != null) return .ambiguous;
                found = a;
            }
        }
        return if (found) |f| .{ .unique = f } else .none;
    }

    pub fn findArgByShort(self: *const Command, c: u8) ?*const Arg {
        for (self.arg_list.items) |*a| {
            if (a.matchesShort(c)) return a;
        }
        return null;
    }

    pub fn findArgById(self: *const Command, id: []const u8) ?*const Arg {
        for (self.arg_list.items) |*a| {
            if (std.mem.eql(u8, a.id, id)) return a;
        }
        return null;
    }

    pub fn getPositional(self: *const Command, index: usize) ?*const Arg {
        for (self.arg_list.items) |*a| {
            if (a.index == index) return a;
        }
        return null;
    }

    pub fn findSubcommand(self: *const Command, name: []const u8) ?*const Command {
        for (self.subcommands.items) |*sc| {
            if (sc.matchesName(name)) return sc;
        }
        return null;
    }

    pub const SubInfer = union(enum) { none, ambiguous, unique: *const Command };

    /// Ambiguity-aware prefix lookup over subcommand names + aliases
    /// (clap's `infer_subcommands`). Prefixes of one subcommand are unique even
    /// when several of its aliases match.
    pub fn inferSubcommand(self: *const Command, prefix: []const u8) SubInfer {
        var found: ?*const Command = null;
        for (self.subcommands.items) |*sc| {
            if (sc.anyNameStartsWith(prefix)) {
                if (found != null) return .ambiguous;
                found = sc;
            }
        }
        return if (found) |f| .{ .unique = f } else .none;
    }

    /// `inferSubcommand` over long-flag subcommand names + long-flag aliases.
    pub fn inferFlagSubcommandLong(self: *const Command, prefix: []const u8) SubInfer {
        var found: ?*const Command = null;
        for (self.subcommands.items) |*sc| {
            if (sc.anyLongFlagStartsWith(prefix)) {
                if (found != null) return .ambiguous;
                found = sc;
            }
        }
        return if (found) |f| .{ .unique = f } else .none;
    }

    fn anyNameStartsWith(self: *const Command, prefix: []const u8) bool {
        if (std.mem.startsWith(u8, self.name, prefix)) return true;
        if (self.aliases_list) |al| {
            for (al) |x| if (std.mem.startsWith(u8, x, prefix)) return true;
        }
        if (self.visible_aliases_list) |al| {
            for (al) |x| if (std.mem.startsWith(u8, x, prefix)) return true;
        }
        return false;
    }

    fn anyLongFlagStartsWith(self: *const Command, prefix: []const u8) bool {
        if (self.long_flag) |l| if (std.mem.startsWith(u8, l, prefix)) return true;
        if (self.long_flag_aliases_list) |al| {
            for (al) |x| if (std.mem.startsWith(u8, x, prefix)) return true;
        }
        if (self.visible_long_flag_aliases_list) |al| {
            for (al) |x| if (std.mem.startsWith(u8, x, prefix)) return true;
        }
        return false;
    }

    /// Whether `name` is this command's name or one of its aliases.
    pub fn matchesName(self: *const Command, name: []const u8) bool {
        if (std.mem.eql(u8, self.name, name)) return true;
        if (self.aliases_list) |al| {
            for (al) |x| if (std.mem.eql(u8, x, name)) return true;
        }
        if (self.visible_aliases_list) |al| {
            for (al) |x| if (std.mem.eql(u8, x, name)) return true;
        }
        return false;
    }

    /// A subcommand whose short flag (or short-flag alias) is `c`.
    pub fn findFlagSubcommandShort(self: *const Command, c: u8) ?*const Command {
        for (self.subcommands.items) |*sc| {
            if (sc.matchesShortFlag(c)) return sc;
        }
        return null;
    }

    /// A subcommand whose long flag (or long-flag alias) is `name`.
    pub fn findFlagSubcommandLong(self: *const Command, name: []const u8) ?*const Command {
        for (self.subcommands.items) |*sc| {
            if (sc.matchesLongFlag(name)) return sc;
        }
        return null;
    }

    fn matchesShortFlag(self: *const Command, c: u8) bool {
        if (self.short_flag == c) return true;
        if (self.short_flag_aliases_list) |al| {
            for (al) |x| if (x == c) return true;
        }
        if (self.visible_short_flag_aliases_list) |al| {
            for (al) |x| if (x == c) return true;
        }
        return false;
    }

    fn matchesLongFlag(self: *const Command, name: []const u8) bool {
        if (self.long_flag) |l| if (std.mem.eql(u8, l, name)) return true;
        if (self.long_flag_aliases_list) |al| {
            for (al) |x| if (std.mem.eql(u8, x, name)) return true;
        }
        if (self.visible_long_flag_aliases_list) |al| {
            for (al) |x| if (std.mem.eql(u8, x, name)) return true;
        }
        return false;
    }

    /// The binary name shown in this command's own usage line. For a flag
    /// subcommand the trailing name segment becomes `{name|--long|-short}`
    /// (clap's flag-subcommand usage name).
    pub fn usageName(self: *const Command, allocator: std.mem.Allocator) []const u8 {
        if (self.short_flag == null and self.long_flag == null) return self.displayName();
        const base = self.bin_name orelse self.name;
        const prefix = if (std.mem.lastIndexOfScalar(u8, base, ' ')) |i| base[0 .. i + 1] else "";
        var b: std.ArrayListUnmanaged(u8) = .empty;
        b.appendSlice(allocator, prefix) catch @panic("clap: OOM");
        b.appendSlice(allocator, "{") catch @panic("clap: OOM");
        b.appendSlice(allocator, self.name) catch @panic("clap: OOM");
        if (self.long_flag) |l| {
            b.appendSlice(allocator, "|--") catch @panic("clap: OOM");
            b.appendSlice(allocator, l) catch @panic("clap: OOM");
        }
        if (self.short_flag) |c| {
            b.appendSlice(allocator, "|-") catch @panic("clap: OOM");
            b.append(allocator, c) catch @panic("clap: OOM");
        }
        b.appendSlice(allocator, "}") catch @panic("clap: OOM");
        return b.items;
    }

    pub fn findGroup(self: *const Command, id: []const u8) ?*const ArgGroup {
        for (self.groups.items) |*g| {
            if (std.mem.eql(u8, g.id, id)) return g;
        }
        return null;
    }

    /// Whether `a` belongs to group `g` (via `Arg.group()` or `ArgGroup.args()`).
    pub fn argInGroup(self: *const Command, a: *const Arg, g: *const ArgGroup) bool {
        _ = self;
        if (a.group_id) |gid| {
            if (std.mem.eql(u8, gid, g.id)) return true;
        }
        for (g.member_ids) |id| {
            if (std.mem.eql(u8, id, a.id)) return true;
        }
        return false;
    }

    /// Membership by group id — also resolves implicit groups (a group named only
    /// via `Arg.group("x")`, with no `ArgGroup` object).
    pub fn argInGroupId(self: *const Command, a: *const Arg, id: []const u8) bool {
        if (a.group_id) |gid| {
            if (std.mem.eql(u8, gid, id)) return true;
        }
        if (self.findGroup(id)) |g| {
            for (g.member_ids) |m| {
                if (std.mem.eql(u8, m, a.id)) return true;
            }
        }
        return false;
    }

    /// Whether `id` names a group (declared or implicit) rather than an argument.
    pub fn isGroupId(self: *const Command, id: []const u8) bool {
        if (self.findGroup(id) != null) return true;
        for (self.arg_list.items) |*a| {
            if (a.group_id) |gid| {
                if (std.mem.eql(u8, gid, id)) return true;
            }
        }
        return false;
    }

    /// Whether `a` belongs to any group (declared or implicit). Such an arg's own
    /// `required` is overridden by the group's requirement (clap's group_overrides_required).
    pub fn argInAnyGroup(self: *const Command, a: *const Arg) bool {
        if (a.group_id != null) return true;
        for (self.groups.items) |*g| {
            if (self.argInGroup(a, g)) return true;
        }
        return false;
    }

    /// Whether `a` is a member of any `required` group (such args are shown in a
    /// group token in usage rather than under `[OPTIONS]`).
    pub fn argInRequiredGroup(self: *const Command, a: *const Arg) bool {
        for (self.groups.items) |*g| {
            if (g.is_required and self.argInGroup(a, g)) return true;
        }
        return false;
    }
};

const testing = std.testing;

test "command: builds tree and assigns positional indices" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const cmd = Command.init(a, "git")
        .about("A fictional versioning CLI")
        .subcommandRequired(true)
        .subcommand(Command.init(a, "clone")
            .about("Clones repos")
            .arg(Arg.fromUsage("<REMOTE>", "The remote to clone")))
        .subcommand(Command.init(a, "diff")
        .arg(Arg.fromUsage("base: [COMMIT]", null))
        .arg(Arg.fromUsage("head: [COMMIT]", null)));

    try testing.expect(cmd.subcommand_required);
    try testing.expectEqualStrings("A fictional versioning CLI", cmd.about_text.?);
    try testing.expectEqual(@as(usize, 2), cmd.subcommands.items.len);

    const diff = cmd.findSubcommand("diff").?;
    try testing.expectEqual(@as(usize, 1), diff.getPositional(1).?.index.?);
    try testing.expectEqualStrings("base", diff.getPositional(1).?.id);
    try testing.expectEqualStrings("head", diff.getPositional(2).?.id);

    const clone = cmd.findSubcommand("clone").?;
    try testing.expectEqualStrings("REMOTE", clone.findArgById("REMOTE").?.id);
}
