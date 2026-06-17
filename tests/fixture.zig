const std = @import("std");
const clap = @import("clap");
const git = @import("git");

const Command = clap.Command;

/// The git command tree is defined once, in the example program; tests reuse it.
pub fn buildGit(a: std.mem.Allocator) Command {
    return git.cli(a);
}

/// Arena-backed harness around the git command (built + tree-propagated).
pub const Fixture = struct {
    arena: std.heap.ArenaAllocator,
    root: Command,

    pub fn init() Fixture {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        var root = buildGit(arena.allocator());
        root.buildTree();
        return .{ .arena = arena, .root = root };
    }
    pub fn deinit(self: *Fixture) void {
        self.arena.deinit();
    }
    pub fn allocator(self: *Fixture) std.mem.Allocator {
        return self.arena.allocator();
    }
    pub fn run(self: *Fixture, argv: []const []const u8) clap.Outcome {
        return clap.parse(self.arena.allocator(), &self.root, argv);
    }
    pub fn runValidated(self: *Fixture, argv: []const []const u8) clap.Outcome {
        return clap.getMatches(self.arena.allocator(), &self.root, argv);
    }
};

// Expected help text, mirroring clap's git.md but rendering the real binary name
// (`git`) for clap's `git[EXE]` placeholder:
// https://github.com/clap-rs/clap/blob/master/examples/git.md

pub const root_help =
    "A fictional versioning CLI\n" ++
    "\n" ++
    "Usage: git <COMMAND>\n" ++
    "\n" ++
    "Commands:\n" ++
    "  clone  Clones repos\n" ++
    "  diff   Compare two commits\n" ++
    "  push   pushes things\n" ++
    "  add    adds things\n" ++
    "  stash  \n" ++
    "  help   Print this message or the help of the given subcommand(s)\n" ++
    "\n" ++
    "Options:\n" ++
    "  -h, --help  Print help\n";

pub const add_help =
    "adds things\n" ++
    "\n" ++
    "Usage: git add <PATH>...\n" ++
    "\n" ++
    "Arguments:\n" ++
    "  <PATH>...  Stuff to add\n" ++
    "\n" ++
    "Options:\n" ++
    "  -h, --help  Print help\n";

pub const diff_help =
    "Compare two commits\n" ++
    "\n" ++
    "Usage: git diff [OPTIONS] [COMMIT] [COMMIT] [-- <PATH>]\n" ++
    "\n" ++
    "Arguments:\n" ++
    "  [COMMIT]  \n" ++
    "  [COMMIT]  \n" ++
    "  [PATH]    \n" ++
    "\n" ++
    "Options:\n" ++
    "      --color[=<WHEN>]  [default: auto] [possible values: always, auto, never]\n" ++
    "  -h, --help            Print help\n";

pub const stash_push_help =
    "Usage: git stash push [OPTIONS]\n" ++
    "\n" ++
    "Options:\n" ++
    "  -m, --message <MESSAGE>  \n" ++
    "  -h, --help               Print help\n";

pub const stash_pop_help =
    "Usage: git stash pop [STASH]\n" ++
    "\n" ++
    "Arguments:\n" ++
    "  [STASH]  \n" ++
    "\n" ++
    "Options:\n" ++
    "  -h, --help  Print help\n";

pub const stash_flatten_help =
    "Usage: git stash [OPTIONS]\n" ++
    "       git stash push [OPTIONS]\n" ++
    "       git stash pop [STASH]\n" ++
    "       git stash apply [STASH]\n" ++
    "       git stash help [COMMAND]...\n" ++
    "\n" ++
    "Options:\n" ++
    "  -m, --message <MESSAGE>  \n" ++
    "  -h, --help               Print help\n" ++
    "\n" ++
    "git stash push:\n" ++
    "  -m, --message <MESSAGE>  \n" ++
    "  -h, --help               Print help\n" ++
    "\n" ++
    "git stash pop:\n" ++
    "  -h, --help  Print help\n" ++
    "  [STASH]     \n" ++
    "\n" ++
    "git stash apply:\n" ++
    "  -h, --help  Print help\n" ++
    "  [STASH]     \n" ++
    "\n" ++
    "git stash help:\n" ++
    "Print this message or the help of the given subcommand(s)\n" ++
    "  [COMMAND]...  Print help for the subcommand(s)\n";
