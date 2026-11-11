# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-09

### Added
- **Unopinionated Core SSG (`#import "@preview/thyme:0.1.0": *`)**:
  - Pure-Typst `bundle`, `html`, and `paged` compilation driven exclusively by standard `typst compile` and `typst watch` (zero external wrapper CLI, zero client-side JavaScript runtime).
  - `site(...)` (with `blog.site` delegation), `webpage(...)`, `mount(path(...))`, `file(...)`, `page-asset(...)`, `query-pages()`, and `backlinks(...)` with $O(1)$ enclosing-document lookup, cross-bundle `@label` links, collision-free heading anchor `id`s (`h1`–`h6`, `-2`/`-3` deduplication + `"section"` symbol fallback) + optional `§` permalinks (`heading-permalinks`), `404.html`, `robots.txt`, `sitemap.xml`, and optional `rss.xml` / `atom.xml`.
  - **Shared AST Traversal (`src/tree.typ`)**: `find-content`, `any-content`, `collect-content`, and subtree-short-circuiting `map-containers` across layout blocks and `html.elem` wrappers.
  - **Typed Hypertagged HTML & Hyperscript (`src/htm.typ`)**: `htm(...)` (`developit/htm`-style HTML fragments with `{slot}` Typst `content` interpolation) and `h(...)` CSS-selector hyperscript (delegating numeric/fractional spacing to `std.h`) with $O(n)$ cluster slicing, `<pre>`/`<textarea>` whitespace preservation, inline-boundary newline space preservation across tags, empty-element `[]` safety, prose word-count hints, 55+ named + decimal `&#...;` + hex `&#x...;` HTML entity decoding, HTML5 optional-close unwinding (`<li>`, `<p>`, `<dt>`/`<dd>`, `<tr>`/`<td>`), explicit tag-mismatch diagnostics, `"false"` boolean attribute omission, and typed `html.*` construction.
  - **Syntactic HTML MathML Normalizer (`with-html-math`)**: Pure AST `show` rules (zero `measure()`, zero SVG) unwrapping single-line auto-`math.lr` delimiters (`$F(e)$`) while keeping tall delimiters stretchy (`$F(union.sq.big_n d_n)$`) and coercing lone operator glyphs in scripts (`$d^*$`) to `math.class("normal", ...)`.
  - **Tadi Web `.typ` Source Transparency**: Capability `path(...)` mounting (`src: path("site.typ")`, `#mount(path("..."))`, `#post(path("..."))`) reads and co-emits verbatim `.typ` sources at sibling URLs (`/site.typ`, `/<slug>.typ`, `/posts/<slug>.typ`) with `.typ` links in the top utility bar and `<link rel="alternate" type="text/plain">` discovery.
  - **Single-URL Zero-JS CSS i18n & `hreflang` (`src/i18n.typ`)**: `#tr(en: [...], de: [...])` and `@preview/linguify`-compatible `lang.toml` dictionary lookup (`#tr("key", from: toml("lang.toml"))`) with per-branch `set text(lang: code)` (honored in paged PDF output as well), primary-branch-only word-count isolation, keyboard-accessible visually-hidden radio controls + `:focus-visible` ring, conditional `en · de` top-bar switcher only on bilingual pages, and `alternates` (`<link rel="alternate" hreflang="...">` + `xhtml:link` in `sitemap.xml`).
  - **Syndication, Full-HTML Feeds & Academic SEO (`src/seo.typ`)**: Structured XML `sitemap.xml`, Atom 1.0 (`atom.xml`), and RSS 2.0 (`rss.xml` with inferred `<lastBuildDate>`) via `@preview/syndicate:0.1.0` supporting both `"summary"` and `"full"` semantic HTML (`content-to-feed-html` with `<table>` and cross-bundle `<label>` URL resolution), dynamic Atom `<id>` epoch inference, and opt-in OpenGraph (`og:*`, `article:*`) + Google Scholar Highwire (`citation_*`) `<meta>` tags (`render-seo-meta`).
- **Scholarly Monochrome Blog Preset (`#import "@preview/thyme:0.1.0": blog` / `blog.site`)**:
  - Unified directly onto `core.typ` so `webpage` subpages (`#mount`), `favicon`, per-post `theme` CSS custom-property overrides, and user `stylesheets` work seamlessly inside `blog` sites.
  - Perceptual `oklch` / `oklab` + `light-dark()` monochrome stylesheet with full-byte 32-bit FNV-1a content-addressed `?v=<hash>` cache keys (`short-hash`), zero-reflow keyboard-accessible narrow-screen sidenote expansion, `@media (prefers-reduced-motion: reduce)`, and dedicated two-column `@media print` preservation.
  - Unified _STIX Two Text_ + _STIX Two Math_, _Helvetica Neue_, and _Commit Mono_ stacks with deterministic zero-`local()` `@font-face` rules (preserving upstream `smcp`/`c2sc` small caps), one-line self-hosting via `font-base` + `font-version` (`default-woff2-files`), and `font-faces: auto | "cdn" | none | str` control.
  - Conditional copy-button JavaScript (`copy-button: auto | bool`) injected only on pages containing `#zebraw` code blocks (zero `<script>` on codeless pages).
  - Right-margin sidenotes via `@preview/marge:0.1.0` (`sidenote`, `#footnote` redirect, `mcite` & `citations-as-sidenotes` margin bibliography citations, `wide` clearance, and superscript-baseline underlines in paged PDF output via `typographic: false` + `is-sidenote-link`), static `/tags/` & `/tags/<tag>/` archive pages (`tag-pages`, live `tag-cloud` links), `#toc()`, compile-time `#backlinks()`, chronological `#post-nav()`, semantic `<time datetime>` Obsidian `<dl>` frontmatter (`author`, optional `monograph`, `created`, `modified`, prose-only `words` & `reading`, linked `#tag`s), Reader-Mode-safe `spicky`-style math environments (`div.blog-sbox`: `definition`, `theorem`, `lemma`, `proposition`, `corollary`, `example`, `recipe`, `remark`; `proof` with hollow QED `□`; `div.blog-callout[role="note"]`), `#diagram(invert-dark: bool)`, `zebraw`, `tablem`, and `cheq`.
- **Documentation, Tests & Tooling**:
  - `@preview/tidy:0.4.3`-generated reference manual (`docs/manual.pdf`), unit & integration test suite (`tests/unit.typ` + `just check`), `template/`, `examples/{portfolio,blog}/`, `justfile`, and CI + automated Typst Universe Draft PR workflow.

### Fixed
- **`robots.txt` was never emitted.** It is documented in the README, the manual and
  `blog.site`'s doc-comment. `robots-txt` is exported from both modules, and `robots: auto` is a
  public option. No code called the function, so no bundle contained a `robots.txt` and `Sitemap:`
  discovery did not work. The function now runs when `robots` is `auto` and a sitemap is produced.
  Regression assertions are in `tests/unit.typ`.
- **`just fmt` called a command that does not exist.**
  The Typst CLI has no `fmt` subcommand — 0.15.x ships `compile`, `watch`, `init`, `query`,
  `eval`, `fonts`, `update`, `completions`, `info` — so every invocation exited 2 (clap usage
  error) and the CI `Format` job failed on its first real run. All three call sites now use
  `typstyle`, the community formatter, installed by the CI setup action.
- **`theme-color` now follows the active theme everywhere.** `render-core-shell` gained a
  `theme-config` parameter, but three paths never threaded it through: the `blog` preset
  (`render-html-shell` dropped the caller's resolved theme, so a site overriding `paper-light`
  still emitted the default `#f2f2f2`), mounted pages inside a bundle, and both `404.html`
  variants (the built-in one emitted no `theme-color` at all; the preset's emitted none either).
  A custom `content` value for `not-found-page` was also emitted as a bare fragment with no
  `<head>`; it is now wrapped in the core shell like any other document.
- **`unknown variable: shell-theme` in the bundle path.** The theme plumbing referenced a
  variable bound inside `webpage()` from inside `site()`. Typst gives every top-level `#let` its
  own scope, so this failed as soon as the bundle target evaluated the 404 and mounted-page
  branches — which no local check reached, because the node-based compiler skips them entirely.
  `site()` now derives its own theme from `_preset-config`.
- **`release.yaml` could never have run.** `pkg_name`/`pkg_version` were read with a malformed
  `sed` expression (missing the `/p` flag and with a stray `:` inside the pattern), so both were
  always empty and the `typst/packages` PR step would have failed on its first use.
- **CI's Python lint was a silent no-op.** `just lint` only invokes `ruff` when it is on `PATH`,
  and the runner does not ship it; CI now installs it explicitly.
- **The format check never checked anything, and the tree was never formatted.** It formatted
  each file into a temporary tree with a `typstyle --output` flag that does not exist and swallowed
  the failure with `|| cp`, so `cmp` always compared a file against itself and the CI `Format` job
  passed unconditionally. `just fmt` now takes typstyle's own flags, so `just fmt --check` verifies.
  Nineteen of twenty-six `.typ` files were in fact unformatted; `just fmt` has been applied to all
  of them and the whole suite (`tests/unit.typ`, all three bundles, both template posts, the
  manual) still compiles and every content assertion still passes.
- **Release notes could silently publish a placeholder.** `release.yaml` extracted the upcoming
  section with an inline regex that fell back to the single line `Release v<version>` when the
  heading was missing, produced empty notes for an empty section, and matched `[v0.1.0rc1]` for a
  `v0.1.0` query. The `verify` job now requires a dated `## [<version>] - YYYY-MM-DD` heading, and
  the notes step fails on a missing or empty body instead of substituting one, so "the section
  exists" and "the notes are publishable" cannot disagree.
- **`typst.toml` is parsed in one place.** The same `sed -n 's/^version = "…"/\1/p'` appeared
  eleven times across the justfile, a shell script and both workflows. One copy was malformed
  badly enough that `release.yaml` could never have run. Everything now uses `tomllib`.
- **The formatter is pinned to `typstyle` 0.15.1** in the CI setup action (and
  `typst-package-check` to `v0.7.0`, which was previously installed from whatever `master`
  happened to be at release time). typstyle's output changes between releases, so a floating
  version makes local `just fmt` and CI `just fmt --check` disagree.
- **`src/lib.typ` documented a guarantee Typst does not provide.** It claimed `site` is "always
  the core engine" and that "import order never matters"; a star import of the preset
  (`#import blog: *`) does rebind `site`, which is ordinary Typst scoping. The comment now states
  the real rule (import the preset after the core); the corresponding overclaim in this file's
  own `[0.1.0]` entry is corrected too.

### Changed
- **The manual is rebuilt on release, reproducibly.** `docs/manual.pdf` is generated from the
  `///` comments in `src/`; `just release` regenerates it immediately before committing, and the
  build pins `SOURCE_DATE_EPOCH` so the result is stable. The `just docs` recipe is gone. It
  existed only to run one `typst compile` from another recipe, so it is a step now.
- **CI and release workflows restructured.** The seven copy-pasted toolchain install blocks are
  now one composite action (`.github/actions/setup`). Release is `verify` → `github-release` →
  `universe-pr`, with the Universe job gated on a repository variable so an early tag does not
  fail solely because a dependency is not published yet. Added `concurrency` to CI.
  (A stale-`docs/manual.pdf` byte comparison was tried and removed: Typst embeds `/CreationDate`
  in an uncompressed object stream, so a content-identical rebuild never matches byte-for-byte.)
- **The command surface is six recipes: `bump`, `check`, `fmt`, `lint`, `preview`, `release`.**
  `just release` is the only release entry point. It has two read-only modes, `--check` (validate
  a tag against `typst.toml` and `CHANGELOG.md`) and `--notes` (print the section CI publishes).
  `thumbnail` is no longer a recipe, and no recipe only re-encodes one file.

  `just check` compiles the three sites, the unit tests and the manual into a scratch directory
  and reports. It does not write, so a clean `git status` after a run is expected. The two
  committed artefacts, `docs/manual.pdf` and `thumbnail.png`, are rebuilt by `just release` just
  before it commits, so the tag cannot carry a stale archive.

  `just release` also builds `dist/universe/`, the tree submitted to `typst/packages`. There is no
  separate `stage-universe` recipe and no `--allow-vendored` flag, since this project will not
  vendor again. `typst-package-check` decides whether the archive is submittable.
- **`just install-packages` was removed.** It linked this checkout into the OS `@preview` cache
  for editor LSPs. That assumed the dependency was absent from Typst Universe, and this release
  ends that condition. Once syndicate is live, `vendor/` goes and plain `typst watch` resolves
  everything. For the same reason no code branches on `vendor/` now. The directory is temporary,
  and a check for its absence would outlive its purpose.
- **Documentation.** Added `docs/api.md`, which lists the 88 exported names for the core and the
  preset. Two thirds of those names appeared in neither the manual nor the README. Added a README
  *Stability & Versioning* section that states what the version number guarantees and records that
  renames are hard renames with no deprecation aliases; commit history was the only record before.
  Removed a CHANGELOG claim that `webpage` had a `route` alias. No such alias was ever exported.

- **`just release` refuses to tag from a state that CI cannot see.** It now requires a release
  branch rather than `main`/`master`, and requires `HEAD` to equal `origin/<branch>`. A tag on a
  commit that was never pushed, or that the workflow never saw, produces a release against a
  different tree; both cases now stop before anything is written. The commit and the tag are
  pushed in one `--atomic` operation, so a failed tag push cannot leave the release commit on the
  remote without the tag that starts its workflow.
- **The Universe job syncs the fork first.** `bfeitknecht/packages` was 98 commits behind
  `typst/packages`. A branch cut from a stale fork carries unrelated upstream commits, or fails
  to push. The job now runs `gh repo sync` before it branches, and creates the fork if it is
  missing. The workflow header records what each repository setting is for, and the checkout and
  cache actions are on their current major versions.
- **`UNIVERSE_REPO` replaced `UNIVERSE_FORK` and carries the host.** The old variable held an
  `owner/repo` slug, so the fork was assumed to be on `github.com`. It now accepts `owner/repo`,
  `host/owner/repo` or a full URL, and the job splits it into the slug that `gh` takes and the host
  that the git remote needs. The default is unchanged: `github.com/bfeitknecht/packages`. The
  `UNIVERSE_*` prefix is the project-wide convention; `syndicate` and `spicky` adopt it too.

### Removed
- **`@preview/exemel` was replaced by `@preview/syndicate`.** The upstream maintainer declined the
  RSS 2.0 feed and sitemap additions that thyme needs, so those encoders now live in
  `bfeitknecht/syndicate`, which thyme owns. `src/seo.typ` imports `atom`, `rss` and `sitemap` from
  it. The generated XML keeps the same shape: Atom 1.0, RSS 2.0 with `<content:encoded>`, and a
  sitemap `urlset`. `sitemap.urlset` and `atom.feed` take the entries as arguments instead of a
  `urls:`/`posts:` list, and `rss.item` names its summary `description`. A temporary copy sits in
  `vendor/syndicate` until the package reaches Typst Universe.
- `.pre-commit-config.yaml` and `docs/autoformat.md`. The hooks duplicated `just fmt` / `just lint`
  and needed `typstyle` on the host anyway, so CI is the only place the checks are enforced. The
  removed doc also claimed `typst fmt` existed and that `just lint` scanned the justfile; it did
  neither.

[Unreleased]: https://github.com/bfeitknecht/thyme/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bfeitknecht/thyme/releases/tag/v0.1.0
