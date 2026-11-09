#!/usr/bin/env python3
"""Read `typst.toml` fields, or emit them as shell assignments.

The same `sed -n 's/^name = "\\(.*\\)"$/\\1/p'` incantation appeared eleven times across
the justfile, `stage-universe.sh` and two workflows. Each copy is a chance to get the
pattern subtly wrong — one of them did, and silently produced an empty package name.
Parsing TOML with a TOML parser removes the class.

Usage:
    manifest.py get name [version|compiler|entrypoint] [--file typst.toml]
    manifest.py env [--file typst.toml]      # PKG_NAME=... PKG_VER=... lines, for `eval`
"""

from __future__ import annotations

import sys
from pathlib import Path

FIELDS = {
    "name": "PKG_NAME",
    "version": "PKG_VER",
    "compiler": "PKG_COMPILER",
    "entrypoint": "PKG_ENTRYPOINT",
}


def load(path: Path) -> dict:
    raw = path.read_text(encoding="utf-8")
    try:
        import tomllib  # Python 3.11+
    except ModuleNotFoundError:  # pragma: no cover - 3.10 and older
        raise SystemExit(
            "manifest.py: needs Python 3.11+ for tomllib; CI and the dev shell both have it"
        ) from None
    try:
        return tomllib.loads(raw).get("package", {})
    except tomllib.TOMLDecodeError as exc:
        raise SystemExit(f"::error::{path}: invalid TOML: {exc}") from exc


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2

    path = Path("typst.toml")
    if "--file" in argv:
        i = argv.index("--file")
        path = Path(argv[i + 1])
        argv = argv[:i] + argv[i + 2 :]

    cmd, *rest = argv
    package = load(path)

    if cmd == "get":
        if not rest:
            print(__doc__)
            return 2
        field = rest[0]
        if field not in FIELDS:
            raise SystemExit(
                f"::error::unknown field {field!r}; known: {', '.join(FIELDS)}"
            )
        value = package.get(field)
        if not value:
            raise SystemExit(f"::error::{path}: missing required field '{field}'")
        print(value)
        return 0

    if cmd == "env":
        lines = []
        for field, var in FIELDS.items():
            value = package.get(field)
            if not value:
                raise SystemExit(f"::error::{path}: missing required field '{field}'")
            lines.append(f'{var}="{value}"')
        print("\n".join(lines))
        return 0

    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
