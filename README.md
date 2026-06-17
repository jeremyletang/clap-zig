# clap-zig

A command-line argument parser for [Zig](https://ziglang.org), modeled on Rust's
[clap](https://github.com/clap-rs/clap) builder API (the `clap_builder` crate).
The derive/macro layer is intentionally out of scope; everything is the builder API.

## Example

```zig
const std = @import("std");
const clap = @import("clap");

pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();

    var cmd = clap.Command.init(a, "greet")
        .about("Greet someone")
        .arg(clap.Arg.fromUsage("-n --name <NAME>", "Who to greet").required(true))
        .arg(clap.Arg.new("loud").short('l').long("loud").action(.set_true));
    cmd.buildTree();

    const raw = try init.minimal.args.toSlice(a);
    var argv: std.ArrayList([]const u8) = .empty;
    for (raw) |arg| try argv.append(a, arg);

    switch (clap.getMatches(a, &cmd, argv.items[1..])) {
        .matches => |m| {
            const name = m.getOne([]const u8, "name").?;
            if (m.getFlag("loud")) std.debug.print("HELLO {s}!\n", .{name}) else std.debug.print("Hello {s}.\n", .{name});
        },
        .err => |e| std.debug.print("{s}", .{clap.renderError(a, e)}),
    }
}
```

Args can be defined with a clap-style usage string (`Arg.fromUsage("-m --message <MSG>")`)
or the chainable builder (`Arg.new("color").long("color").valueName("WHEN")`).

## Build, run, test

```sh
zig build                       # build the example binaries into zig-out/bin/
zig build test                  # run unit + integration (snapshot) tests
zig build test -Dtest-filter=…  # run a subset

zig build run-git -- diff --color=never        # run the git example
zig build run-escaped_positional -- -f -- a b  # run the escaped-positional example
```

The `examples/` directory ports clap's own examples and is snapshot-tested
byte-for-byte against clap's expected output.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).
