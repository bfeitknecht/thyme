default:
    @just --list

# Populate a temporary local @preview package directory from typst.toml and vendor/*
[private]
_link-pkg dir=".tmp-pkg":
    #!/usr/bin/env sh
    set -eu
    rm -rf "{{dir}}"
    for manifest in typst.toml vendor/*/typst.toml; do
        [ -f "$manifest" ] || continue
        p_dir="$(cd "$(dirname "$manifest")" && pwd)"
        p_name="$(python3 scripts/manifest.py get name --file "$manifest")"
        p_ver="$(python3 scripts/manifest.py get version --file "$manifest")"
        mkdir -p "{{dir}}/preview/$p_name"
        ln -s "$p_dir" "{{dir}}/preview/$p_name/$p_ver"
    done

# Format all Typst files in the repository in place (`just fmt-check` to verify)
fmt:
    #!/usr/bin/env sh
    set -eu
    # The Typst CLI has no `fmt` subcommand (0.15.x ships compile/watch/init/query/
    # eval/fonts/update/completions/info). `typstyle` is the community formatter; it
    # takes paths as positional input and has no `--output`, only `--inplace`/`--check`/`--diff`.
    if ! command -v typstyle >/dev/null 2>&1; then
        echo "typstyle not found — install it with: cargo install typstyle --version 0.15.1 --locked" >&2
        exit 1
    fi
    typstyle --inplace $(find src template examples tests docs -name '*.typ' 2>/dev/null)
    echo "formatted all .typ files"

# Check that every Typst file is already formatted (does not modify the tree)
fmt-check:
    #!/usr/bin/env sh
    set -eu
    if ! command -v typstyle >/dev/null 2>&1; then
        echo "typstyle not found — install it with: cargo install typstyle --version 0.15.1 --locked" >&2
        exit 1
    fi
    # typstyle exits non-zero and prints a unified diff when input is not formatted.
    if ! typstyle --check $(find src template examples tests docs -name '*.typ' 2>/dev/null); then
        echo "unformatted Typst files listed above" >&2
        echo "run 'just fmt' and commit the result" >&2
        exit 1
    fi
    echo "all Typst files are formatted"

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
        ruff check . --exclude vendor,preview
        ruff format --check . --exclude vendor,preview
    fi
    echo "linting passed"

# Run full compilation, XML/sitemap/link/source verification, and Universe staging checks
check:
    #!/usr/bin/env sh
    set -eu
    tmp_pkg=".tmp-pkg"
    tmp_check=".tmp-check"
    tmp_stage=".tmp-stage"
    rm -rf "$tmp_pkg" "$tmp_check" "$tmp_stage"
    trap 'rm -rf "$tmp_pkg" "$tmp_check" "$tmp_stage"' EXIT

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

    if "disabled=" in unit_html or 'data-ok="true"' not in unit_html:
        fail("boolean attr handling failed")
    # Assert the semantics (entities decoded, optional-close <li> unwound + balanced) and
    # stay agnostic about inter-tag whitespace, which differs between exporters.
    if not re.search(r"<li>first</li>\s*<li>second — … …</li>", unit_html):
        m = re.search(r"<li>first.{0,140}", unit_html, re.S)
        fail(f"htm entity/tag-balance test failed; got {m.group(0)!r}" if m else "htm entity/tag-balance test failed; no <li>first")
    if '<div class="empty-box"></div>' not in unit_html or '<div class="empty-htm"></div>' not in unit_html:
        fail("empty h/htm element test failed")
    if "<pre>line 1\n  indented line 2</pre>" not in unit_html:
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
        if "Sitemap:" not in (bundle / "robots.txt").read_text():
            fail(f"missing Sitemap in {bundle}/robots.txt")
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

    # 4. Dry-run Universe directory staging
    sh ./scripts/stage-universe.sh --allow-vendored "$tmp_stage"

    pkg_name="$(python3 scripts/manifest.py get name)"
    pkg_ver="$(python3 scripts/manifest.py get version)"
    if command -v typst-package-check >/dev/null 2>&1 && [ ! -d vendor/exemel ]; then
        typst-package-check check "$tmp_stage/packages/preview/$pkg_name/$pkg_ver"
    fi
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

# Compile docs/manual.typ -> docs/manual.pdf
docs:
    #!/usr/bin/env sh
    set -eu
    tmp_pkg=".tmp-pkg"
    trap 'rm -rf "$tmp_pkg"' EXIT
    just _link-pkg "$tmp_pkg"
    # Reproducible build: pin the PDF creation date so `docs/manual.pdf` is a pure function
    # of the sources. Without this every rebuild rewrites /CreationDate and a
    # "is the manual stale?" check can never pass. 0 = the Unix epoch.
    SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-0}" \
        typst compile --root . --package-path "$tmp_pkg" docs/manual.typ docs/manual.pdf
    echo "built docs/manual.pdf"

# Regenerate thumbnail.png (250 PPI) from template/posts/fixed-points.typ
thumbnail:
    #!/usr/bin/env sh
    set -eu
    tmp_pkg=".tmp-pkg"
    trap 'rm -rf "$tmp_pkg"' EXIT
    just _link-pkg "$tmp_pkg"
    typst compile --package-path "$tmp_pkg" -f png --pages 1 --ppi 250 template/posts/fixed-points.typ thumbnail.png
    if command -v oxipng >/dev/null 2>&1; then
        oxipng -o 4 --strip safe thumbnail.png
    fi
    echo "updated thumbnail.png"

# Stage clean Typst Universe directory -> dist/universe/packages/preview/thyme/<version>
stage-universe out="dist/universe":
    sh ./scripts/stage-universe.sh "{{out}}"

# Link thyme (and any vendor/*) into the local OS @preview package cache for editor LSPs
install-packages:
    #!/usr/bin/env sh
    set -eu
    if [ "$(uname -s)" = "Darwin" ]; then
        cache_root="$HOME/Library/Application Support/typst/packages"
    else
        cache_root="${XDG_DATA_HOME:-$HOME/.local/share}/typst/packages"
    fi
    just _link-pkg "$cache_root"
    echo "linked local @preview packages into $cache_root"

# Bump package version across typst.toml, template/, examples/, tests/unit.typ, docs/manual.typ, and README.md
bump version:
    #!/usr/bin/env python3
    import pathlib, re
    new_ver = "{{version}}".lstrip("v")
    if not re.fullmatch(r"\d+\.\d+\.\d+", new_ver):
        raise SystemExit(f"invalid semver: {new_ver!r}")
    import subprocess
    toml = pathlib.Path("typst.toml")
    old_ver = subprocess.run(
        ["python3", "scripts/manifest.py", "get", "version"],
        check=True, capture_output=True, text=True,
    ).stdout.strip()
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
    print(f"bumped thyme {old_ver} -> {new_ver} (remember to run `just docs` and update CHANGELOG.md)")

# Commit, tag (vX.Y.Z), and push; GitHub Actions cuts the release and opens a Draft PR to typst/packages
release $tag="" $message="":
    #!/usr/bin/env sh
    set -eu

    tag="${tag:-}"
    message="${message:-}"

    if [ -z "$tag" ]; then
        printf 'release tag (e.g. v0.1.0): '
        read -r tag || tag=""
    fi
    if [ -z "$message" ]; then
        printf 'release message: '
        read -r message || message=""
    fi

    if [ -z "$tag" ] || [ -z "$message" ]; then
        echo "release: both tag and message are required" >&2
        exit 1
    fi
    case "$tag" in
        v*) ver="${tag#v}" ;;
        *) echo "release: tag must start with 'v' (e.g. v0.1.0)" >&2; exit 1 ;;
    esac

    toml_ver="$(python3 scripts/manifest.py get version)"
    if [ "$ver" != "$toml_ver" ]; then
        echo "release: tag $tag does not match typst.toml version $toml_ver (run 'just bump $ver' first)" >&2
        exit 1
    fi
    if ! git check-ref-format "refs/tags/$tag" >/dev/null 2>&1; then
        echo "release: '$tag' is not a valid git tag" >&2
        exit 1
    fi
    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
        echo "release: tag $tag already exists" >&2
        exit 1
    fi
    if ! git remote get-url origin >/dev/null 2>&1; then
        echo "release: no 'origin' remote configured" >&2
        exit 1
    fi

    just check
    just fmt-check
    just lint

    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "$message"
    elif git rev-parse -q --verify HEAD >/dev/null; then
        echo "release: clean tree, tagging HEAD"
    else
        echo "release: nothing to commit and no commits yet" >&2
        exit 1
    fi

    git tag -a "$tag" -m "$message"
    git push origin HEAD
    git push origin "$tag"
    echo "release: pushed $tag"
