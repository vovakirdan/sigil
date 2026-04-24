# Sigil

`sigil` is a CLI argument parser for Surge.

It gives you a small typed builder API for flags, options, subcommands, and positional arguments, then parses `rt_argv()` into a `Parsed` value or a diagnostic (`Help(...)` / `ErrorDiag(...)`).

## What It Supports

- boolean flags: `--verbose`, `-v`
- integer options: `--port 8080`, `--port=8080`
- string options: `--config path.toml`, `--config=path.toml`
- one level of subcommands
- positional `many` arguments
- `--` to stop option parsing
- automatic help trigger on `--help` / `-h`

## Add It To A Project

Add `sigil` to `surge.toml`:

```bash
surge module add https://github.com/vovakirdan/sigil.git
```

And see `surge.toml` like this:

```toml
[modules]
  [modules.sigil]
    source = "git"
    url = "https://github.com/vovakirdan/sigil.git"
```

Then import it in Surge:

```surge
import sigil::{AppSpec, Key, Parsed};
import sigil;
```

## Quick Start

This is the minimal shape of a real CLI:

```surge
import sigil::{AppSpec, Key, Parsed};
import sigil;

fn handle_success(parsed: Parsed, add_key: Key, list_key: Key) -> nothing {
    if parsed.get_bool(list_key) {
        print("list mode");
        return nothing;
    }

    let title_res = parsed.get_string(add_key);
    compare title_res {
        Success(title) => print("add: " + title);
        err => {
            let _ = err;
            print("missing --add");
        }
    }
    return nothing;
}

@entrypoint
fn main() {
    let argv = rt_argv();

    let mut app = AppSpec::new("notes");
    let add_key: Key = app.opt_string("--add", Some("-a"), nothing);
    let list_key: Key = app.flag_bool("--list", Some("-l"));

    let result = sigil.parse(argv, &app);
    compare result {
        Success(parsed) => handle_success(parsed, add_key, list_key);
        parse_diag => {
            compare parse_diag {
                sigil.Help(s) => print(s);
                sigil.ErrorDiag(e) => exit(e);
            }
        }
    }
    return nothing;
}
```

Example invocations:

```bash
notes --list
notes --add "buy milk"
notes -a "ship release"
notes --help
```

## Subcommands

`sigil` supports one level of subcommands.

```surge
let mut app = AppSpec::new("tool");
let verbose_key = app.flag_bool("--verbose", Some("-v"));

let mut serve_cmd = app.cmd("serve");
serve_cmd.help("Start the server");
let port_key = serve_cmd.opt_int("--port", Some("-p"), 8080);

let mut build_cmd = app.cmd("build");
build_cmd.help("Build project artifacts");
let release_key = build_cmd.flag_bool("--release", nothing);

let result = sigil.parse(rt_argv(), &app);
compare result {
    Success(parsed) => {
        let verbose = parsed.get_bool(verbose_key);
        let _ = verbose;

        if parsed.is_it("serve") {
            let port_res = parsed.get_int(port_key);
            compare port_res {
                Success(port) => print("serve on " + (port to string));
                err => exit(err);
            }
        }

        if parsed.is_it("build") {
            let release = parsed.get_bool(release_key);
            if release {
                print("building release");
            } else {
                print("building debug");
            }
        }
    }
    parse_diag => {
        compare parse_diag {
            sigil.Help(s) => print(s);
            sigil.ErrorDiag(e) => exit(e);
        }
    }
}
```

## Positional Arguments

Use `positionals_many(...)` when a command accepts tail arguments like file paths:

```surge
let mut app = AppSpec::new("fmt");
let files_key = app.positionals_many("files");

let result = sigil.parse(rt_argv(), &app);
compare result {
    Success(parsed) => {
        let files_res = parsed.get_many(files_key);
        compare files_res {
            Success(files) => {
                let mut i: int = 0;
                while i < (files.__len() to int) {
                    print("file: " + files[i]);
                    i = i + 1;
                }
            }
            err => exit(err);
        }
    }
    parse_diag => {
        compare parse_diag {
            sigil.Help(s) => print(s);
            sigil.ErrorDiag(e) => exit(e);
        }
    }
}
```

This accepts both of these forms:

```bash
fmt a.sg b.sg c.sg
fmt -- a.sg --not-a-flag.sg
```

## Getters And Return Shapes

`sigil.parse(...)` returns:

```surge
Erring<Parsed, sigil.ParseDiag>
```

`Parsed` exposes these getters:

- `get_bool(key) -> bool`
- `get_int(key) -> int!`
- `get_string(key) -> string!`
- `get_many(key) -> string[]!`
- `is_it(name) -> bool`

Example:

```surge
let verbose: bool = parsed.get_bool(verbose_key);

let port_res = parsed.get_int(port_key);
compare port_res {
    Success(port) => print("port=" + (port to string));
    err => exit(err);
}
```

`get_bool(...)` is convenient for flags because missing means `false`.

`get_many(...)` returns `Success([])` when the positional list is absent.

## Help And Error Handling

`sigil` separates parser help from parser errors:

```surge
let result = sigil.parse(rt_argv(), &app);
compare result {
    Success(parsed) => {
        let _ = parsed;
    }
    parse_diag => {
        compare parse_diag {
            sigil.Help(usage) => {
                print(usage);
            }
            sigil.ErrorDiag(err) => {
                exit(err);
            }
        }
    }
}
```

Current diagnostics cover:

- unknown long flags
- unknown short flags
- missing option values
- invalid integer values
- missing required string options

## Low-Level Lexer Example

If you need raw argv tokenization, `sigil` also exposes the lexer:

```surge
let toks = sigil.lex_argv([
    "build",
    "-v",
    "--port=8080",
    "--",
    "file.sg",
]);
```

The token stream uses:

- `Long(string)`
- `Short(uint32)`
- `Value(string)`
- `Stop()`
- `Pos(string)`

## Supported Argument Forms

Long options:

- `--flag`
- `--opt=value`
- `--opt value`

Short options:

- `-v`
- `-abc`
- `-p8080`

Special handling:

- `--` stops option parsing and sends the rest into positional handling

## Current Limitations

- subcommands are one-level only
- help text is intentionally simple for now
- required checks are currently most useful for string options without defaults
- repeated named options overwrite previous values; positional `many` is the supported multi-value path

## Files

```text
sigil/
├── spec.sg      builder types: AppSpec, CmdSpec, OptSpec, Key
├── tokens.sg    token definitions for argv lexing
├── lexer.sg     argv -> Token[]
├── parse.sg     Token[] -> Parsed / ParseDiag
├── parsed.sg    parsed accessors and typed getters
├── diag.sg      help and parser diagnostics
├── imports.sg   stdlib imports used across the package
└── surge.toml   Surge package manifest
```
