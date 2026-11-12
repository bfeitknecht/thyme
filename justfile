default:
    @just --list

# Populate a throwaway @preview package directory from typst.toml
[private]
_link-pkg dir=".tmp-pkg":
    #!/usr/bin/env sh
    set -eu
    # Throwaway package path for `typst compile --package-path`: map this checkout to
    # @preview/thyme so the sources resolve without a published release. Every other
    # @preview import resolves from the OS package cache.
    name="$(python3 -c 'import tomllib; print(tomllib.load(open("typst.toml", "rb"))["package"]["name"])')"
    version="$(python3 -c 'import tomllib; print(tomllib.load(open("typst.toml", "rb"))["package"]["version"])')"
    rm -rf "{{dir}}"
    mkdir -p "{{dir}}/preview/$name"
    ln -s "$(pwd)" "{{dir}}/preview/$name/$version"

# Format every .typ file (`just fmt --check` verifies without writing)
fmt args="--inplace":
    #!/usr/bin/env sh
    set -eu
    # The Typst CLI has no `fmt` subcommand (0.15.x ships compile/watch/init/query/
    # eval/fonts/update/completions/info); `typstyle` is the community formatter. It
    # takes paths positionally and has no `--output`, only `--inplace`/`--check`/`--diff`.
    if ! command -v typstyle >/dev/null 2>&1; then
        echo "typstyle not found — install it with: cargo install typstyle --version 0.15.1 --locked" >&2
        exit 1
    fi
    typstyle {{args}} $(find src template examples tests docs -name '*.typ' 2>/dev/null)

# Lint Typst files and Python scripts
lint:
    #!/usr/bin/env sh
    set -eu
    # Check Typst syntax (basic compilation check)
    trap 'rm -rf ".tmp-lint"' EXIT
    just _link-pkg ".tmp-lint"
    typst compile --package-path ".tmp-lint" --features html,bundle --format bundle template/site.typ .tmp-lint/lint-check

    # Python linting (if ruff is available)
    if command -v ruff >/dev/null 2>&1; then
        ruff check .
        ruff format --check .
    fi
    echo "linting passed"

# Verify the whole repository: compiles everything, checks XML/links/sources. Reads only.
check:
    #!/usr/bin/env sh
    set -eu
    tmp_pkg=".tmp-pkg"
    tmp_check=".tmp-check"
    rm -rf "$tmp_pkg" "$tmp_check"
    trap 'rm -rf "$tmp_pkg" "$tmp_check"' EXIT

    just _link-pkg "$tmp_pkg"
    mkdir -p "$tmp_check"

    # 1. Compile template & all examples as HTML bundles
    for site_dir in template examples/portfolio examples/blog; do
        out_dir="$tmp_check/$(echo "$site_dir" | tr '/' '_')"
        typst compile --package-path "$tmp_pkg" --features html,bundle --format bundle "$site_dir/site.typ" "$out_dir"
    done

    # 2. Compile unit tests, standalone HTML & paged PDF targets
    typst compile --root . --package-path "$tmp_pkg" tests/unit.typ "$tmp_check/unit.pdf"
    typst compile --root . --package-path "$tmp_pkg" --features html --format html tests/unit.typ "$tmp_check/unit.html"
    typst compile --package-path "$tmp_pkg" --features html --format html template/posts/fixed-points.typ "$tmp_check/fixed-points.html"
    typst compile --package-path "$tmp_pkg" template/posts/fixed-points.typ "$tmp_check/fixed-points.pdf"
    typst compile --package-path "$tmp_pkg" template/posts/minimal-bundles.typ "$tmp_check/minimal-bundles.pdf"
    # The manual is generated from the `///` comments in src/, so it has to build. It is
    # compiled into the scratch directory: `just check` reports, it does not write.
    typst compile --root . --package-path "$tmp_pkg" docs/manual.typ "$tmp_check/manual.pdf"

    # 3. Validate generated sitemap.xml, robots.txt, RSS/Atom XML, .typ sources, tags, backlinks, a11y, and internal href targets
    python3 - "$tmp_check" <<'PY'
    import pathlib, re, sys, xml.etree.ElementTree as ET

    def fail(msg):
        # GitHub Actions turns `::error::` into a job annotation with the message attached.
        print(f"::error::{msg}")
        raise SystemExit(1)

    base = pathlib.Path(sys.argv[1])
    unit_html = (base / "unit.html").read_text()

    # Native `html.*` constructors are Typst's own, so the test asserts that `thyme` does
    # not interfere with them: an attribute value stays the string it was given, an empty
    # element keeps its open/close pair, and nesting is preserved.
    if '<button disabled="false" data-ok="true">' not in unit_html:
        fail("attribute rendering failed")
    if '<div class="empty-box"></div>' not in unit_html:
        fail("empty native element lost its self-closing form")
    if not re.search(r"<li>first</li>\s*<li>second — … …</li>", unit_html):
        m = re.search(r"<li>first.{0,140}", unit_html, re.S)
        fail(f"native element nesting failed; got {m.group(0)!r}" if m else "native element nesting failed")
    # The exporter writes a real newline inside `<pre>`, so the literal is built rather
    # than written: a real newline would break this Python block across two lines.
    pre_literal = "<pre><code>line 1" + chr(10) + "  indented line 2</code></pre>"
    if pre_literal not in unit_html:
        fail("<pre> whitespace preservation failed")
    if '<mo form="prefix" stretchy="false">(</mo><mi>𝑒</mi><mo stretchy="false">)</mo>' not in unit_html:
        fail("with-html-math failed to suppress auto-lr stretch on F(e)")
    if '<msup><mi>𝑑</mi><mi>∗</mi></msup>' not in unit_html or '<msup><mi>ℝ</mi><mi>+</mi></msup>' not in unit_html:
        fail("with-html-math failed to normalize lone script operators")
    if '<mrow><mo>(</mo><mfrac><mi>𝑎</mi><mi>𝑏</mi></mfrac><mo>)</mo></mrow>' not in unit_html:
        fail("with-html-math broke stretchy frac delimiters")
    if '<mrow><mo>(</mo><mi>𝑒</mi><mo>)</mo></mrow>' not in unit_html:
        fail("with-html-math broke explicit lr((e))")
    if "font-variant-caps: small-caps" not in unit_html or "font-variant-caps: all-small-caps" not in unit_html:
        fail("smallcaps HTML export failed")

    for bundle in sorted(p for p in base.iterdir() if p.is_dir()):
        try:
            ET.fromstring((bundle / "sitemap.xml").read_text())
        except Exception as e:
            fail(f"invalid {bundle}/sitemap.xml: {e}")
        # `robots` and `llms` are pass-through files: the bundle carries exactly the bytes
        # the author pointed at, or no file at all. Assert that, because it is the contract
        # that replaced generating them.
        # Only the blog example opts in, by pointing at `examples/blog/*.txt`. The bundle
        # directory is named after the site path with `/` replaced, so match that rather
        # than the bare name. Compare against the repository file, not against the bundle
        # itself, or the check passes no matter what the recipe does.
        opts_in = bundle.name == "examples_blog"
        for name in ("robots.txt", "llms.txt"):
            got = bundle / name
            if opts_in:
                source = pathlib.Path.cwd() / "examples" / "blog" / name
                if not got.is_file():
                    fail(f"missing {bundle}/{name}")
                if got.read_bytes() != source.read_bytes():
                    fail(f"{bundle}/{name} is not a byte-for-byte copy of {source}")
            elif got.exists():
                fail(f"{bundle}/{name} exists but the site did not pass `path(...)`")
        # The Tadi source for the home page is `site.typ` (`source-path-for("index.html")`),
        # not `index.typ`. Assert the documented mapping rather than a literal name.
        if not (bundle / "site.typ").is_file():
            fail(f"missing Tadi site.typ in {bundle}")
        if "<script" in (bundle / "index.html").read_text():
            fail(f"unexpected <script> on codeless {bundle}/index.html")
        if (bundle / "atom.xml").exists():
            try:
                ET.fromstring((bundle / "atom.xml").read_text())
            except Exception as e:
                fail(f"invalid {bundle}/atom.xml: {e}")
        if (bundle / "rss.xml").exists():
            rss_txt = (bundle / "rss.xml").read_text()
            try:
                ET.fromstring(rss_txt)
            except Exception as e:
                fail(f"invalid {bundle}/rss.xml: {e}")
            if "<lastBuildDate>" not in rss_txt:
                fail(f"missing <lastBuildDate> in {bundle}/rss.xml")
        for html_file in sorted(bundle.rglob("*.html")):
            txt = html_file.read_text()
            if ">??" in txt or "[??]" in txt:
                fail(f"unresolved ref in {html_file}")
            for href in re.findall(r'href="([^"#?]+)', txt):
                if href.startswith(("http://", "https://", "mailto:", "javascript:", "data:")):
                    continue
                target = (html_file.parent / href.lstrip("/")) if not href.startswith("/") else (bundle / href.lstrip("/"))
                if not target.resolve().exists():
                    fail(f"broken href={href!r} in {html_file}")

    blog_b = base / "examples_blog"
    if not ((blog_b / "about/index.html").is_file() and (blog_b / "about.typ").is_file()):
        fail("mounted webpage about/ missing html or .typ source")
    if not ((blog_b / "tags/index.html").is_file() and (blog_b / "tags/algebra/index.html").is_file()):
        fail("static tags/ archive pages missing")
    tags_idx = (blog_b / "tags/index.html").read_text()
    if 'algebra/index.html">#algebra</a>' not in tags_idx:
        fail("tag-cloud failed to emit live <a> links")
    sm_html = (blog_b / "posts/state-machine/index.html").read_text()
    bi_html = (blog_b / "posts/bilingual-notes/index.html").read_text()
    if '<footer class="blog-backlinks">' not in sm_html:
        fail("missing blog-backlinks footer")
    if '<nav class="blog-post-nav"' not in sm_html:
        fail("missing post-nav")
    if '<time datetime="' not in sm_html:
        fail("missing semantic <time datetime>")
    if '<div class="blog-sbox"' not in bi_html or '<aside class="blog-sbox"' in bi_html:
        fail("blog-sbox must be a Reader-Mode-safe <div>, not <aside>")
    if 'aria-label="Language: en"' not in bi_html or 'aria-label="Toggle sidenote 1"' not in sm_html:
        fail("missing a11y labels on language switcher / sidenote toggle")
    if '<nav class="blog-toc"' not in bi_html:
        fail("missing blog-toc")
    if "citation_technical_report_number" not in bi_html:
        fail("missing Scholar citation meta")
    if '<content type="html">' not in (blog_b / "atom.xml").read_text():
        fail("atom.xml missing full-HTML <content>")
    if "<content:encoded>" not in (blog_b / "rss.xml").read_text():
        fail("rss.xml missing <content:encoded>")

    print("verified unit tests, sitemap.xml, robots.txt, full-HTML feeds, live tag-cloud links, Reader-Mode divs, a11y controls, .typ sources, and internal hrefs across all 3 bundles")
    PY

    echo "all checks passed"

# Compile template + examples into a browsable preview/ site (open preview/index.html)
preview:
    #!/usr/bin/env sh
    set -eu
    tmp_pkg=".tmp-pkg"
    out="preview"
    trap 'rm -rf "$tmp_pkg"' EXIT
    just _link-pkg "$tmp_pkg"

    rm -rf "$out"
    mkdir -p "$out"
    typst compile --package-path "$tmp_pkg" --features html,bundle --format bundle template/site.typ "$out/template"
    typst compile --package-path "$tmp_pkg" --features html,bundle --format bundle examples/blog/site.typ "$out/blog"
    typst compile --package-path "$tmp_pkg" --features html,bundle --format bundle examples/portfolio/site.typ "$out/portfolio"

    # The landing page reuses the `theme-color` tags thyme itself emitted for the
    # template build, so the palette has exactly one source of truth (src/blog/theme.typ).
    {
    cat <<'HTML'
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>thyme &mdash; preview</title>
    HTML
      grep -o '<meta name="theme-color"[^>]*>' "$out/template/index.html"
    cat <<'HTML'
        <style>
          :root {
            color-scheme: light dark;
            --paper: light-dark(oklch(96% 0 0), oklch(17% 0 0));
            --surface: light-dark(oklch(92% 0 0), oklch(27% 0 0));
            --text: light-dark(oklch(21% 0 0), oklch(95% 0 0));
            --muted: light-dark(oklch(47% 0 0), oklch(70% 0 0));
            --rule: color-mix(in oklab, var(--muted) 30%, var(--paper));
          }
          * { box-sizing: border-box; }
          body {
            max-width: 46rem;
            margin: 0 auto;
            padding: clamp(3rem, 8vw, 7rem) clamp(1.25rem, 4vw, 2rem);
            background: var(--paper);
            color: var(--text);
            font: 1.0625rem/1.65 "STIX Two Text", Georgia, serif;
            -webkit-font-smoothing: antialiased;
          }
          header { margin-bottom: clamp(2.5rem, 6vw, 4.5rem); }
          h1 {
            margin: 0 0 0.75rem;
            font-family: ui-monospace, Menlo, monospace;
            font-size: clamp(1.75rem, 4vw, 2.25rem);
            font-weight: 500;
            letter-spacing: -0.03em;
          }
          .tagline { margin: 0; max-width: 34ch; color: var(--muted); }
          ul { margin: 0; padding: 0; list-style: none; }
          li + li { border-top: 1px solid var(--rule); }
          li:first-child { border-top: 1px solid var(--rule); }
          li:last-child { border-bottom: 1px solid var(--rule); }
          a {
            display: flex;
            align-items: baseline;
            justify-content: space-between;
            gap: 1.5rem;
            padding: 1.15rem 0.25rem;
            color: inherit;
            text-decoration: none;
          }
          a:hover .name { text-decoration: underline; text-underline-offset: 0.25em; }
          .name { font-weight: 500; }
          .kind {
            flex: none;
            padding: 0.2rem 0.55rem;
            border-radius: 999px;
            background: var(--surface);
            color: var(--muted);
            font: 0.7rem/1 ui-monospace, Menlo, monospace;
            letter-spacing: 0.06em;
            text-transform: uppercase;
          }
          .path {
            display: block;
            margin-top: 0.3rem;
            color: var(--muted);
            font: 0.75rem/1.4 ui-monospace, Menlo, monospace;
          }
          footer {
            margin-top: clamp(3rem, 7vw, 5rem);
            padding-top: 1.25rem;
            border-top: 1px solid var(--rule);
            color: var(--muted);
            font: 0.8rem/1.6 ui-monospace, Menlo, monospace;
          }
          footer a { display: inline; padding: 0; }
          @media (max-width: 30rem) {
            a { flex-direction: column-reverse; align-items: flex-start; gap: 0.5rem; }
          }
        </style>
      </head>
      <body>
        <header>
          <h1>thyme preview</h1>
          <p class="tagline">A monochrome Typst &rarr; HTML static-site engine. Three builds, compiled locally.</p>
        </header>
        <ul>
          <li>
            <a href="template/index.html">
              <span><span class="name">Template</span> &mdash; folio<span class="path">template/site.typ</span></span>
              <span class="kind">core</span>
            </a>
          </li>
          <li>
            <a href="blog/index.html">
              <span><span class="name">Blog preset</span> &mdash; noether<span class="path">examples/blog/site.typ</span></span>
              <span class="kind">blog</span>
            </a>
          </li>
          <li>
            <a href="portfolio/index.html">
              <span><span class="name">Portfolio</span> &mdash; zero built-in CSS<span class="path">examples/portfolio/site.typ</span></span>
              <span class="kind">core</span>
            </a>
          </li>
        </ul>
        <footer>Live reload: <code>typst watch --features html,bundle -f bundle template/site.typ preview/template --serve</code></footer>
      </body>
    </html>

    HTML
    } > "$out/index.html"
    echo "preview written to $out/index.html"
    echo "live reload: typst watch --features html,bundle -f bundle template/site.typ preview/template --serve"

# Build the exact directory submitted to typst/packages. Called by `release` and by CI.
[private]
_stage out name version:
    #!/usr/bin/env python3
    import pathlib, shutil, subprocess, sys

    name, version = "{{name}}", "{{version}}"

    # Every @preview/<name>:<version> import must name the version being staged.
    expected = f"@preview/{name}:{version}"
    stale = subprocess.run(
        ["grep", "-rn", f"@preview/{name}:", "template", "examples", "tests/unit.typ",
         "docs/manual.typ", "README.md"],
        capture_output=True, text=True,
    ).stdout
    stale = chr(10).join(l for l in stale.splitlines() if expected not in l)
    if stale:
        sys.exit(f"stage: imports do not name {expected}:" + chr(10) + stale)

    dest = pathlib.Path("{{out}}") / "packages" / "preview" / name / version
    shutil.rmtree(dest, ignore_errors=True)
    (dest / "docs").mkdir(parents=True)
    (dest / "assets").mkdir()
    for item in ("typst.toml", "LICENSE", "README.md", "thumbnail.png"):
        shutil.copy2(item, dest)
    for item in ("src", "template", "examples"):
        shutil.copytree(item, dest / item)
    shutil.copy2("docs/manual.pdf", dest / "docs" / "manual.pdf")
    for item in ("preview-light.png", "preview-dark.png"):
        shutil.copy2(pathlib.Path("assets") / item, dest / "assets" / item)
    for stray in dest.rglob(".DS_Store"):
        stray.unlink()

# Bump package version across typst.toml, template/, examples/, tests/unit.typ, docs/manual.typ, and README.md
bump version:
    #!/usr/bin/env python3
    import pathlib, re, tomllib
    new_ver = "{{version}}".lstrip("v")
    if not re.fullmatch(r"\d+\.\d+\.\d+", new_ver):
        raise SystemExit(f"invalid semver: {new_ver!r}")
    toml = pathlib.Path("typst.toml")
    old_ver = tomllib.loads(toml.read_text())["package"]["version"]
    toml.write_text(re.sub(r'^version = "[^"]+"', f'version = "{new_ver}"', toml.read_text(), count=1, flags=re.M))
    targets = (
        list(pathlib.Path("template").rglob("*.typ"))
        + list(pathlib.Path("examples").rglob("*.typ"))
        + [pathlib.Path("tests/unit.typ"), pathlib.Path("docs/manual.typ"), pathlib.Path("README.md")]
    )
    for p in targets:
        txt = p.read_text()
        txt = txt.replace(f"@preview/thyme:{old_ver}", f"@preview/thyme:{new_ver}")
        if p.name == "manual.typ":
            txt = txt.replace(f"v{old_ver}", f"v{new_ver}")
        p.write_text(txt)
    print(f"bumped thyme {old_ver} -> {new_ver} (then update CHANGELOG.md; `just check` rebuilds the manual)")

# Cut a release: `just release [VERSION]`, `just release VERSION --check`, `just release --notes`
release *args:
    #!/usr/bin/env python3
    import os, pathlib, re, subprocess, sys, tomllib

    package = tomllib.loads(pathlib.Path("typst.toml").read_text())["package"]
    version = package["version"]
    changelog = pathlib.Path("CHANGELOG.md").read_text()

    flags = [a for a in "{{args}}".split() if a.startswith("--")]
    positional = [a for a in "{{args}}".split() if not a.startswith("--")]
    unknown = [f for f in flags if f not in ("--check", "--notes")]
    if unknown:
        sys.exit(f"release: unknown flag {unknown[0]} (expected --check or --notes)")
    if len(flags) > 1:
        sys.exit(f"release: --check and --notes are mutually exclusive (got {flags})")
    if len(positional) > 1:
        sys.exit(
            f"release: expected at most one argument (the version), got {positional}. "
            "The commit message is prompted for at cut time."
        )
    # The argument is the version, without a `v`. The tag is derived from it, because a
    # release tag is `v<version>` and typing that prefix by hand adds nothing.
    given = positional[0] if positional else ""
    if not given and "--notes" not in flags:
        sys.exit("release: pass a version, e.g. `just release 0.1.0`")
    if given.startswith("v"):
        sys.exit(
            f"release: pass the version without a 'v' prefix (got {given!r}, want {given[1:]!r})"
        )
    tag = f"v{given}" if given else ""

    # The release notes are this section of CHANGELOG.md. Both read-only modes need them,
    # and so does the publish step.
    match = re.search(
        rf"^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## \[|^\[[^\]]+\]:|\Z)",
        changelog,
        re.M | re.S,
    )
    notes = match.group(1).strip() if match else ""

    if "--notes" in flags:
        if not notes:
            sys.exit(f"CHANGELOG.md has no '## [{version}]' section to publish")
        print(notes)
        sys.exit(0)

    problems = []
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        problems.append(f"typst.toml version {version!r} is not plain X.Y.Z")
    if tag != f"v{version}":
        problems.append(
            f"version {given!r} does not match typst.toml (want {version!r}; run `just bump` first)"
        )
    if not re.search(rf"^## \[{re.escape(version)}\] - \d\d\d\d-\d\d-\d\d", changelog, re.M):
        problems.append(f"CHANGELOG.md needs a dated '## [{version}] - YYYY-MM-DD' section")
    elif not notes:
        problems.append(f"'## [{version}]' in CHANGELOG.md is empty")
    if "--check" not in flags:
        if subprocess.run(["git", "check-ref-format", f"refs/tags/{tag}"], capture_output=True).returncode:
            problems.append(f"{tag!r} is not a valid git tag")
        elif not subprocess.run(["git", "rev-parse", "-q", "--verify", f"refs/tags/{tag}"], capture_output=True).returncode:
            problems.append(f"tag {tag} already exists")
        if subprocess.run(["git", "remote", "get-url", "origin"], capture_output=True).returncode:
            problems.append("no 'origin' remote configured")

        # A tag on a commit that origin does not have produces a release whose workflow
        # either never runs or runs against a different tree. The branch itself does not
        # matter: tagging the default branch is normal for a single-maintainer project.
        branch = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True,
        ).stdout.strip()
        subprocess.run(["git", "fetch", "--quiet", "--tags", "origin"], check=False)
        head = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        remote = subprocess.run(
            ["git", "rev-parse", f"origin/{branch}"], capture_output=True, text=True,
        )
        if remote.returncode:
            problems.append(f"origin has no branch {branch!r}; push it first")
        elif remote.stdout.strip() != head:
            problems.append(
                f"HEAD is not what origin has for {branch!r}; push or pull first"
            )

    for problem in problems:
        print(f"::error::{problem}")
    if problems:
        sys.exit(1)
    if "--check" in flags:
        print(f"{tag} is ready: typst.toml, CHANGELOG.md and the tag agree")
        sys.exit(0)

    # Run the full gate, then rebuild the committed artefacts so the tag cannot carry a
    # stale manual or thumbnail.
    for gate in (["check"], ["fmt", "--check"], ["lint"]):
        subprocess.run(["just", *gate], check=True)

    subprocess.run(
        ["just", "_link-pkg", ".tmp-pkg"],
        check=True,
    )
    # SOURCE_DATE_EPOCH pins the PDF creation date so the committed manual is reproducible.
    subprocess.run(
        ["typst", "compile", "--root", ".", "--package-path", ".tmp-pkg",
         "docs/manual.typ", "docs/manual.pdf"],
        check=True,
        env={**os.environ, "SOURCE_DATE_EPOCH": "0"},
    )
    subprocess.run(
        ["typst", "compile", "--package-path", ".tmp-pkg", "-f", "png",
         "--pages", "1", "--ppi", "250",
         "template/posts/fixed-points.typ", "thumbnail.png"],
        check=True,
    )
    subprocess.run(["just", "_stage", "dist/universe", package["name"], version], check=True)

    try:
        message = input(f"release message [{tag}]: ").strip() or tag
    except EOFError:
        message = tag
    subprocess.run(["git", "add", "-A"], check=True)
    if subprocess.run(["git", "diff", "--cached", "--quiet"], capture_output=True).returncode:
        subprocess.run(["git", "commit", "-m", message], check=True)
    subprocess.run(["git", "tag", "-a", tag, "-m", message], check=True)
    # One push, so a failed tag push cannot leave the release commit on the remote
    # without the tag that triggers its workflow.
    subprocess.run(["git", "push", "--atomic", "origin", "HEAD", tag], check=True)
    print(f"released {tag}; CI is cutting the GitHub release and the Typst Universe PR")
