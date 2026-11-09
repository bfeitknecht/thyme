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
        p_name="$(sed -n 's/^name = "\(.*\)":' "$manifest")"
        p_ver="$(sed -n 's/^version = "\(.*\)":' "$manifest")"
        mkdir -p "{{dir}}/preview/$p_name"
        ln -s "$p_dir" "{{dir}}/preview/$p_name/$p_ver"
    done

# Autoformat all Typst files in the repository
fmt:
    #!/usr/bin/env sh
    set -eu
    # Typst 0.15.1+ supports `typst fmt`
    for f in src/**/*.typ template/**/*.typ examples/**/*.typ tests/**/*.typ docs/**/*.typ; do
        [ -f "$f" ] || continue
        typst fmt "$f"
    done
    echo "formatted all .typ files"

# Lint Typst files and Python scripts
lint:
    #!/usr/bin/env sh
    set -eu
    # Check Typst syntax (basic compilation check)
    just _link-pkg ".tmp-lint"
    typst compile --package-path ".tmp-lint" --features html,bundle --format bundle template/site.typ .tmp-lint/lint-check
    
    # Python linting (if ruff is available)
    if command -v ruff >/dev/null 2>&1; then
        ruff check .
        ruff format --check .
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
    base = pathlib.Path(sys.argv[1])
    unit_html = (base / "unit.html").read_text()
    assert 'disabled=' not in unit_html and 'data-ok="true"' in unit_html, "boolean attr handling failed"
    assert "<li>first</li><li>second — … …</li>" in unit_html, "htm entity/tag-balance test failed"
    assert '<div class="empty-box"></div>' in unit_html and '<div class="empty-htm"></div>' in unit_html, "empty h/htm element test failed"
    assert "<pre>line 1\n  indented line 2</pre>" in unit_html, "<pre> whitespace preservation failed"
    assert '<mo form="prefix" stretchy="false">(</mo><mi>𝑒</mi><mo stretchy="false">)</mo>' in unit_html, "with-html-math failed to suppress auto-lr stretch on F(e)"
    assert '<msup><mi>𝑑</mi><miarchiwizowane></msup>' in unit_html and '<msup><mi>ℝ</mi><mi>+</mi></msup>' in unit_html, "with-html-math failed to normalize lone script operators"
    assert '<mrow><mo>(</mo><mfrac><mi>𝑎</mi><mi>𝑏</mi></mfrac><mo>)</mo></mrow>' in unit_html, "with-html-math broke stretchy frac delimiters"
    assert '<mrow><mo>(</mo><mi>𝑒</mi><mo>)</mo></mrow>' in unit_html, "with-html-math broke explicit lr((e))"
    assert 'font-variant-caps: small-caps' in unit_html and 'font-variant-caps: all-small-caps' in unit_html, "smallcaps HTML export failed"

    for bundle in sorted(p for p in base.iterdir() if p.is_dir()):
        ET.fromstring((bundle / "sitemap.xml").read_text())
        assert "Sitemap:" in (bundle / "robots.txt").read_text(), f"missing Sitemap in {bundle}/robots.txt"
        assert (bundle / "index.typ").is_file(), f"missing Tadi index.typ in {bundle}"
        assert "<script" not in (bundle / "index.html").read_text(), f"unexpected <script> on codeless {bundle}/index.html"
        if (bundle / "atom.xml").exists():
            ET.fromstring((bundle / "atom.xml").read_text())
        if (bundle / "rss.xml").exists():
            rss_txt = (bundle / "rss.xml").read_text()
            ET.fromstring(rss_txt)
            assert "<lastBuildDate>" in rss_txt, f"missing <lastBuildDate> in {bundle}/rss.xml"
        for html_file in sorted(bundle.rglob("*.html")):
            txt = html_file.read_text()
            assert ">??" not in txt and "[??]" not in txt, f"unresolved ref in {html_file}"
            for href in re.findall(r'href="([^"#?]+)', txt):
                if href.startswith(("http://", "https://", "mailto:", "javascript:", "data:")):
                    continue
                target = (html_file.parent / href.lstrip("/")) if not href.startswith("/") else (bundle / href.lstrip("/"))
                assert target.resolve().exists(), f"broken href={href!r} in {html_file}"

    blog_b = base / "examples_blog"
    assert (blog_b / "about/index.html").is_file() and (blog_b / "about.typ").is_file()
    assert (blog_b / "tags/index.html").is_file() and (blog_b / "tags/algebra/index.html").is_file()
    tags_idx = (blog_b / "tags/index.html").read_text()
    assert '<a href="algebra/index.html">#algebra</a>' in tags_idx or 'algebra/index.html">#algebra</a>' in tags_idx, "tag-cloud failed to emit live <a> links"
    sm_html = (blog_b / "posts/state-machine/index.html").read_text()
    bi_html = (blog_b / "posts/bilingual-notes/index.html").read_text()
    assert '<footer class="blog-backlinks">' in sm_html
    assert '<nav class="blog-post-nav"' in sm_html
    assert '<time datetime="' in sm_html
    assert '<div class="blog-sbox"' in bi_html and '<aside class="blog-sbox"' not in bi_html
    assert 'aria-label="Language: en"' in bi_html and 'aria-label="Toggle sidenote 1"' in sm_html
    assert '<nav class="blog-toc"' in bi_html
    assert 'citation_technical_report_number' in bi_html
    assert '<content type="html">' in (blog_b / "atom.xml").read_text()
    assert '<content:encoded>' in (blog_b / "rss.xml").read_text()
    print("verified unit tests, sitemap.xml, robots.txt, full-HTML feeds, live tag-cloud links, Reader-Mode divs, a11y controls, .typ sources, and internal hrefs across all 3 bundles")
    PY

    # 4. Dry-run Universe directory staging
    sh ./scripts/stage-universe.sh --allow-vendored "$tmp_stage"

    pkg_name="$(sed -n 's/^name = "\(.*\)":' typst.toml)"
    pkg_ver="$(sed -n 's/^version = "\(.*\)":' typst.toml)"
    if command -v typst-package-check >/dev/null 2>&1 && [ ! -d vendor/exemel ]; then
        typst-package-check check "$tmp_stage/packages/preview/$pkg_name/$pkg_ver"
    fi
    echo "all checks passed"

# Compile docs/manual.typ -> docs/manual.pdf
docs:
    #!/usr/bin/env sh
    set -eu
    tmp_pkg=".tmp-pkg"
    trap 'rm -rf "$tmp_pkg"' EXIT
    just _link-pkg "$tmp_pkg"
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
    toml = pathlib.Path("typst.toml")
    old_m = re.search(r'^version = "([^"]+)"', toml.read_text(), re.M)
    old_ver = old_m.group(1)
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

    toml_ver="$(sed -n 's/^version = "\(.*\)":' typst.toml)"
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
    just fmt
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
