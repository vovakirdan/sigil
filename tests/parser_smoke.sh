#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/deps"
mkdir -p "$tmp/deps/sigil"
cp "$repo_root"/*.sg "$repo_root/surge.toml" "$tmp/deps/sigil/"
mkdir -p "$tmp/app"

cat > "$tmp/surge.toml" <<'TOML'
[package]
name = "sigil_downstream_smoke"
version = "0.1.0"
root = "."

[run]
main = "app"

[modules.sigil]
source = "git"
url = "https://github.com/vovakirdan/sigil.git"
TOML

cat > "$tmp/app/main.sg" <<'SG'
pragma binary;

import ../sigil as sigil;

fn check(cond: bool, msg: string) -> nothing {
    if !cond {
        panic(msg);
    }
    return nothing;
}

fn check_int(res: Erring<int, Error>, expected: int, msg: string) -> nothing {
    compare res {
        Success(actual) => check(actual == expected, msg);
        err => {
            let _ = err;
            panic(msg);
        }
    };
    return nothing;
}

fn check_string(res: Erring<string, Error>, expected: string, msg: string) -> nothing {
    compare res {
        Success(actual) => check(actual == expected, msg);
        err => {
            let _ = err;
            panic(msg);
        }
    };
    return nothing;
}

fn check_many(res: Erring<string[], Error>, expected_a: string, expected_b: string) -> nothing {
    compare res {
        Success(actual) => {
            check(actual.__len() == 2:uint, "many len");
            check(actual[0] == expected_a, "many first");
            check(actual[1] == expected_b, "many second");
        }
        err => {
            let _ = err;
            panic("many result failed");
        }
    };
    return nothing;
}

fn check_error(args: string[], app: &sigil.AppSpec, expected: string) -> nothing {
    compare sigil.parse(args, app) {
        Success(_) => panic("expected parse error, got success");
        diag => compare diag {
            sigil.ErrorDiag(err) => check(err.message == expected, "wrong parse error");
            sigil.Help(_) => panic("expected parse error, got help");
        };
    };
    return nothing;
}

fn defaults() -> nothing {
    let mut app = sigil.AppSpec::new("tool");
    let verbose = app.flag_bool("--verbose", Some("-v"));
    let port = app.opt_int("--port", Some("-p"), 8080);
    let name = app.opt_string("--name", Some("-n"), Some("World"));

    let args: string[] = [];
    compare sigil.parse(args, &app) {
        Success(parsed) => {
            check(!parsed.get_bool(verbose), "default bool");
            check_int(parsed.get_int(port), 8080, "default int");
            check_string(parsed.get_string(name), "World", "default string");
        }
        diag => {
            let _ = diag;
            panic("defaults parse failed");
        }
    };
    return nothing;
}

fn long_values() -> nothing {
    let mut app = sigil.AppSpec::new("tool");
    let port = app.opt_int("--port", Some("-p"), 8080);
    let name = app.opt_string("--name", Some("-n"), nothing);

    let args: string[] = ["--port", "9090", "--name=Ada"];
    compare sigil.parse(args, &app) {
        Success(parsed) => {
            check_int(parsed.get_int(port), 9090, "long int");
            check_string(parsed.get_string(name), "Ada", "long string");
        }
        diag => {
            let _ = diag;
            panic("long values parse failed");
        }
    };
    return nothing;
}

fn short_values() -> nothing {
    let mut app = sigil.AppSpec::new("tool");
    let verbose = app.flag_bool("--verbose", Some("-v"));
    let port = app.opt_int("--port", Some("-p"), 8080);
    let name = app.opt_string("--name", Some("-n"), nothing);

    let args: string[] = ["-v", "-p4242", "-n", "Bob"];
    compare sigil.parse(args, &app) {
        Success(parsed) => {
            check(parsed.get_bool(verbose), "short bool");
            check_int(parsed.get_int(port), 4242, "short int");
            check_string(parsed.get_string(name), "Bob", "short string");
        }
        diag => {
            let _ = diag;
            panic("short values parse failed");
        }
    };
    return nothing;
}

fn positionals() -> nothing {
    let mut app = sigil.AppSpec::new("tool");
    let files = app.positionals_many("files");

    let args: string[] = ["src.sg", "--", "--literal"];
    compare sigil.parse(args, &app) {
        Success(parsed) => check_many(parsed.get_many(files), "src.sg", "--literal");
        diag => {
            let _ = diag;
            panic("positionals parse failed");
        }
    };
    return nothing;
}

fn help_flag() -> nothing {
    let mut app = sigil.AppSpec::new("tool");
    let _ = app.flag_bool("--verbose", Some("-v"));

    let args: string[] = ["--help"];
    compare sigil.parse(args, &app) {
        Success(_) => panic("expected help, got success");
        diag => compare diag {
            sigil.Help(usage) => check(usage == "usage: tool [command] [options] [--] [args...]", "help usage");
            sigil.ErrorDiag(_) => panic("expected help, got error");
        };
    };
    return nothing;
}

fn parse_errors() -> nothing {
    let mut app = sigil.AppSpec::new("tool");
    let _ = app.flag_bool("--verbose", Some("-v"));
    let _ = app.opt_int("--port", Some("-p"), 8080);
    let _ = app.opt_string("--name", Some("-n"), nothing);

    let unknown: string[] = ["--unknown"];
    check_error(unknown, &app, "unknown flag: --unknown");

    let missing_long: string[] = ["--port", "--verbose"];
    check_error(missing_long, &app, "missing value for --port");

    let missing_short: string[] = ["-n", "-v"];
    check_error(missing_short, &app, "missing value");

    let invalid_int: string[] = ["--port", "nope"];
    check_error(invalid_int, &app, "invalid int for --port");
    return nothing;
}

@entrypoint
fn main() -> int {
    defaults();
    long_values();
    short_values();
    positionals();
    help_flag();
    parse_errors();
    return 0;
}
SG

(
    cd "$tmp"
    surge diag .
    surge run app
    surge build --backend llvm app
)
