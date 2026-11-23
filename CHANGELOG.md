# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Layout knobs for a site stylesheet.** CSS variables a site can set from its own
  `stylesheets:` file: `--heading-weight`, `--title-size` and `--title-tracking` (the
  homepage title), `--page-title-size`, `--entry-title-size` and `--topbar-space`. The
  defaults keep the current look.
- The homepage `<main>` carries `class="home"`, so a stylesheet can address its title.

### Changed

- The scroll hint of a wide table is a straight shadow of even strength from top to
  bottom, a little stronger. It was a radial gradient, faint and round, under a fading
  cover.
- An inline code chip no longer breaks across lines (`white-space: nowrap`).

## [0.1.4] - 2026-11-24

### Added

- **Site navigation in the top bar.** `blog.site(nav: ("/", "/posts/", "/tags/"))`
  puts path-style section links (`span.site-nav`) in the top bar of every page in place
  of the `/..` backlink: homepage, posts, pages, tag archives and `404.html`. An entry is a
  site-root path, shown as its own label, or `(href: ..., label: ...)`. The section that
  holds the page is marked `aria-current="page"` (`/` only on the homepage). Hrefs are
  relative, so a bundle still browses from disk; the 404 page keeps them absolute.

### Changed

- A table in `wide` stays in the reading column and scrolls sideways (it spilled into the sidenote margin).

### Fixed

- A folder post `posts/<name>/index.typ` gets the slug `<name>` (URL `/posts/<name>/`), as
  documented, instead of `index`; `<dir>/index.typ` pages route to `<dir>/index.html`. Only
  `<name>/site.typ` was handled.
- A sidenote inside a table cell no longer floats onto the next column; on wide screens it sits under its text.

## [0.1.3] - 2026-11-20

### Changed

- **Entry cards: the reading time sits beside the title, the date alone on the right edge.**
  Title and reading time form one group (`div.entry-title`), so on a narrow screen the
  reading time wraps under the title, never between title and date. The leading `·` is gone.
  Paged output reads `<n> min · <date>` on the right, the date last.

## [0.1.2] - 2026-11-18

### Added

- **Entry cards can show an estimated reading time.** `blog.site(show-reading: true)`
  puts `· <n> min` beside the date on every entry card: homepage `#post(...)` mounts,
  `#posts()` listings, and tag archive pages. The estimate reuses the post's own
  `base-words` + `<thyme-word-hint>` tally and `wpm`, so it always matches the
  `words` / `reading` rows on the post page. The date and the reading time share one
  right-aligned meta group (`span.when`); with no date, the reading time stands alone.

### Changed

- The `.when` meta group on entry cards is a `span` that wraps the `<time>` element
  (it was the class of the `<time>` element itself). Styling is unchanged.

## [0.1.1] - 2026-11-16

### Fixed

- **Wide tables scroll sideways in HTML.** Every table in a `blog` post is wrapped in a
  `.blog-table` scroll container. Before, a narrow screen squeezed the table to fit.
- **Inline code in table cells no longer breaks.** The mobile rule
  `overflow-wrap: anywhere` broke code chips one character per line. Code in cells now
  stays on one line, and the table scrolls.
- **Proof boxes scroll sideways** when their content is wider than the column.
- **Docs no longer say that `robots.txt` is generated.** The `site` doc comment and the
  template sample post now match the behaviour: the file is copied only when you pass
  `robots: path(...)`.

## [0.1.0] - 2026-11-12

First release. Requires Typst 0.15.0 or later.

### The public surface is seven names

Making markup your own is Typst's job. A site writes plain Typst content, and reaches for
`html.elem` when content cannot express what it needs. `thyme` stays out of the way.

- **No HTML builder of its own.** Markup that plain Typst content cannot express goes
  through Typst's typed `html.*` constructors: `html.elem("div", attrs: (class: "note"), body)`.
  Inline math, `@label` references and components interpolate as usual.
- **The surface is `site`, `webpage`, `mount`, `file`, `backlinks`, `tr`, `robots-txt`**,
  plus `blog` for the preset. Everything else is a module-level function: importable, with
  stable module paths, and without a compatibility promise. `docs/api.md` lists what left
  and why.
- **What the engine applies is not exported.** MathML normalisation is applied by the page
  shell, feeds and the sitemap are emitted by `site`, and a page's assets go in its
  `assets:` parameter.

### Core

- **`site(...)` compiles a Typst directory into a static site.** One `typst compile --features html,bundle`
  writes `index.html`, every mounted page, `404.html`, `sitemap.xml`,
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
  [`@preview/syndicate:0.1.0`](https://github.com/bfeitknecht/syndicate), with `feed-content: "summary" | "full"`
  selecting compact descriptions or full semantic HTML. Pages carry
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
- **`just release X.Y.Z` cuts a release.** It takes the version, derives the `vX.Y.Z` tag, checks
  it against `typst.toml` and this file, runs the full gate, rebuilds `docs/manual.pdf` and `thumbnail.png`,
  then pushes the commit and the tag together. The tag starts a workflow that publishes the GitHub Release and
  submits the package to Typst Universe.
