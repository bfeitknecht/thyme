#!/usr/bin/env python3
"""Extract one version's release notes from CHANGELOG.md.

`release.yaml` used to inline a regex for this, which failed silently: a missing section
fell back to a placeholder string, an empty one produced empty notes, and a `[v0.1.0rc1]`
heading matched a `v0.1.0` query. Extracting structured data from prose needs to fail
loudly, not politely.

Usage:
    changelog.py notes <version>            # markdown body for the release, on stdout
    changelog.py check <version> <tag>      # validate before publishing; exit 1 on problems
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

CHANGELOG = Path("CHANGELOG.md")

# A version heading: `## [1.2.3] - 2024-01-01`, `## [1.2.3]`, `## [Unreleased]`.
HEADING = re.compile(r"^## \[(?P<version>[^\]]+)\]", re.M)
# Keep a Changelog link definitions (`[0.1.0]: https://...`) terminate a section.
LINK_DEF = re.compile(r"^\[[^\]]+\]:", re.M)
# A version must be exactly what typst.toml declares: no prefix, no suffix.
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def sections(text: str) -> dict[str, str]:
    """Map version -> section body, using the heading positions as boundaries."""
    heads = list(HEADING.finditer(text))
    out: dict[str, str] = {}
    for i, m in enumerate(heads):
        start = m.end()
        # the heading line ends at the next newline
        nl = text.find("\n", start)
        start = len(text) if nl == -1 else nl + 1
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        body = text[start:end]
        # strip trailing link definitions and blank padding
        lm = LINK_DEF.search(body)
        if lm:
            body = body[: lm.start()]
        version = m.group("version").strip()
        # a duplicate heading is a real authoring error, not something to silently pick
        if version in out:
            raise SystemExit(f"::error::CHANGELOG.md has two '## [{version}]' sections")
        out[version] = body.strip()
    return out


def notes(version: str) -> str:
    try:
        body = sections(CHANGELOG.read_text()).get(version)
    except SystemExit as exc:
        print(str(exc).removeprefix("::error::"), file=sys.stderr)
        raise
    if body is None:
        known = ", ".join(
            k for k in sections(CHANGELOG.read_text()) if k != "Unreleased"
        )
        raise SystemExit(
            f"::error::no '## [{version}]' section in CHANGELOG.md "
            f"(found: {known}). Refusing to publish empty release notes."
        )
    if not body.strip():
        raise SystemExit(
            f"::error::'## [{version}]' in CHANGELOG.md is empty. "
            "Refusing to publish empty release notes."
        )
    return body


def check(version: str, tag: str) -> int:
    problems: list[str] = []

    if not SEMVER.match(version):
        problems.append(f"typst.toml version {version!r} is not plain X.Y.Z")

    expected_tag = f"v{version}"
    if tag != expected_tag:
        problems.append(
            f"tag {tag!r} does not match typst.toml version (expected {expected_tag!r})"
        )

    try:
        body = sections(CHANGELOG.read_text()).get(version)
    except SystemExit as exc:
        problems.append(str(exc).removeprefix("::error::"))
        body = None

    if body is None:
        problems.append(f"no '## [{version}]' section in CHANGELOG.md")
    elif not body.strip():
        problems.append(f"'## [{version}]' in CHANGELOG.md is empty")
    else:
        # a released version should not be the accumulating bucket
        if not re.search(
            rf"^## \[{re.escape(version)}\]\s*-\s*\d{{4}}-\d{{2}}-\d{{2}}",
            CHANGELOG.read_text(),
            re.M,
        ):
            problems.append(
                f"'## [{version}]' has no release date (want '## [{version}] - YYYY-MM-DD')"
            )
        if "### " not in body:
            problems.append(
                f"'## [{version}]' has no '### Added/Fixed/...' subsections"
            )

    for p in problems:
        print(f"::error::{p}")
    if problems:
        return 1

    print(f"changelog: {version} section present, dated, and non-empty")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[0] == "notes":
        print(notes(argv[1]))
        return 0
    if len(argv) >= 3 and argv[0] == "check":
        return check(argv[1], argv[2])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
