# Zigthing (name pending)

Have you ever saved a zig file and ZLS says there are no errors then you build it and there are errors? Has that ever annoyed you? Then this plugin is perfect for you

A *very* small wrapper around `zig build check --watch` that puts the output into quickfix then into buffer diagnostics. This makes it so that you get *all* the diagnostics from zig build. Since zig's update builds are so fast, the diagnostics appear roughly at the same time as ZLS's do

For the diagnostics to appear, you have to save the file (as that's the thing that tells `zig build --watch` to update)

## Requirements

This plugin requires that your build.zig has a check step:

```zig
    const exe = b.addExecutable(.{
        // ...
    });

    const check = b.step("check", "check");
    check.dependOn(&exe.step);
```

## Features

Currently the only feature is that it starts the process when you enter a zig file

This process will not stop until it dies or until neovim dies/exits

## Installation

With lazy.nvim:

```lua
{
    -- no need to lazy load, it does all that with an ftplugin file
    "CWood-sdf/zigthing.nvim",
}
```
