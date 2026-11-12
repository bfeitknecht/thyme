# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-12

First release. Requires Typst 0.15.1 or later.

### The public surface is seven names

Making markup your own is Typst's job. A site writes plain Typst content, and reaches for
`html.elem` when content cannot express what it needs. `thyme` stays out of the way.

- **No HTML builder of its own.** Markup that plain Typst content cannot express goes
  through Typst's typed `html.*` constructors: `html.elem("div", attrs: (class: "note"),
  body)`. Inline math, `@label` references and components interpolate as usual.
- **The surface is `site`, `webpage`, `mount`, `file`, `backlinks`, `tr`, `robots-txt`**,
  plus `blog` for the preset. Everything else is a module-level function: importable, with
  stable module paths, and without a compatibility promise. `docs/api.md` lists what left
  and why.
- **What the engine applies is not exported.** MathML normalisation is applied by the page
  shell, feeds and the sitemap are emitted by `site`, and a page's assets go in its
  `assets:` parameter.

### Core

- **`site(...)` compiles a Typst directory into a static site.** One `typst compile
  --features html,bundle` writes `index.html`, every mounted page, `404.html`, `sitemap.xml`,
  optional RSS 2.0 and Atom 1.0 feeds, and a sibling `.typ` source for each page. No wrapper
  CLI and no client-side JavaScript.
- **Pages are ordinary Typst files.** `webpage(...)` declares one, `mount(path(...))` includes
  it, and `site(...)` reads every declared page to build feeds, sitemaps and backlinks from
  the same data. `backlinks(...)` resolves links across the whole bundle.
- **Headings get stable anchors.** `h1`–`h6` `id`s are collision-free (`-2`/`-3`
  deduplication, a `"section"` fallback), and `heading-permalinks` adds a `§` link.
- **Exported math is normalised.** Automatic delimiters and lone script operators are
  rewritten, so MathML reads correctly to a screen reader and a scraper. The page shell
  applies it, so a site never installs the rule itself.
- **`#tr(...)` gives one URL several languages.** Text switches on a hidden radio control with no
  JavaScript, `set text(lang:)` carries through to paged output, and `alternates` emits
  `hreflang` links in the page and in `sitemap.xml`. A page that declares its languages must
  translate every block: `site` and `blog.post` panic on a missing branch and name the language,
  because a gap is obvious on a two-language page and easy to ship on a six-language one.
- **Feeds, sitemaps and metadata are emitted by `site(...)`.** XML is built through
  [`@preview/syndicate:0.1.0`](https://github.com/bfeitknecht/syndicate), with `feed-content:
  "summary" | "full"` selecting compact descriptions or full semantic HTML. Pages carry
  OpenGraph and Google Scholar Highwire tags.

### Blog preset

- **`blog.site(...)` is a monochrome scholarly blog.** It builds on `site(...)`, so subpages,
  favicon, per-post theme overrides and custom stylesheets still work.
- **The theme is colourless by construction.** `oklch` with zero chroma and `light-dark()`
  covers both schemes, `prefers-reduced-motion` is honoured, and the two-column print layout
  is kept. Stylesheet URLs carry a content hash, so a deploy cannot serve a stale file.
- **Fonts are self-hostable.** STIX Two Text and Math, Helvetica Neue and Commit Mono resolve
  through `font-base` plus `font-version`, with deterministic `@font-face` rules that keep the
  upstream small-caps features.
- **Scholarly furniture.** `@preview/marge` sidenotes, `mcite` margin citations, `/tags/`
  archives with a live tag cloud, `#toc()`, post navigation, and Reader-Mode-safe
  environments for `definition`, `theorem`, `lemma`, `proposition`, `corollary`, `example`,
  `proof`, `remark` and `recipe`.

### Files you provide

- **`robots.txt` and `llms.txt` are copied, never generated.** `robots: path(...)` and
  `llms: path(...)` put your file in the bundle root byte for byte; leave them unset and the
  site carries no such file. The formats belong to their specifications, not to this package.
  `robots-txt(...)` is exported if you want a starting point.

### Tooling

- **`just` runs everything.** `check` compiles the template, both examples and the manual, then
  validates the generated XML, sources, tag cloud, backlinks, accessibility and internal links
  without writing to the tree. `fmt` and `lint` cover formatting. `preview` serves the template
  with live reload.
- **`just release vX.Y.Z` cuts a release.** It checks the tag against `typst.toml` and this
  file, runs the full gate, rebuilds `docs/manual.pdf` and `thumbnail.png`, then pushes the
  commit and the tag together. The tag starts a workflow that publishes the GitHub Release and
  submits the package to Typst Universe.
