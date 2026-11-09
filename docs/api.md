# API surface

The public surface of `@preview/thyme` is exactly what `src/lib.typ` (core) and `src/blog/mod.typ`
(the `blog` preset) re-export. Everything else in `src/` is private, and anything named with a
leading `_` carries no guarantee at all.

This file is the index; `docs/manual.pdf` is the reference, generated from the source doc-comments.
If a name is listed here but missing from the manual, treat this file as authoritative for
*existence* and the source doc-comment for *behaviour*.

## Core — `#import "@preview/thyme:<v>": *`

### Engine

| Name | Purpose |
| :--- | :--- |
| `site` | Root site bundler: `#show: site.with(title:, url:, ...)`. |
| `webpage` | A mounted sub-page document (`webpage[body]`, `path:` routes it). |
| `mount` | Mount a `.typ` file, a directory, or a literal body into the bundle. |
| `file` | Co-emit an arbitrary static file (bytes or path) at a bundle route. |
| `page-asset` | Declare a per-document asset (font, image, download) with its URL. |
| `query-pages` | Query all mounted pages in the current site (title, path, meta). |
| `backlinks` | Compile-time backlink list for the current document. |

### Typed HTML / hyperscript

| Name | Purpose |
| :--- | :--- |
| `htm` | Tagged-template HTML fragments with `{slot}` content interpolation. |
| `h` | CSS-selector hyperscript (`h("div.card", ...)`). |
| `enable-htm` | Enable `htm` parsing for the scope it is shown into. |
| `with-html-math` | AST normaliser for inline MathML in HTML export. |

### i18n

| Name | Purpose |
| :--- | :--- |
| `tr` | Inline translation: `tr(en: [...], de: [...])` or a `lang.toml` key. |
| `lang-switcher` | Zero-JS `:root:has(...)` language switcher. |
| `i18n-css` | The stylesheet that drives the switcher. |
| `resolve-page-langs` | Discover the language set of a document tree. |
| `normalize-alternates` | Normalise `alternates` into `(hreflang, href)` pairs. |

### Paths & slugs

| Name | Purpose |
| :--- | :--- |
| `slugify` | Unicode-aware slug generation. |
| `heading-anchor-id` | Collision-free heading anchor ids (dedupe + symbol fallback). |
| `source-path-for` | `.typ` source URL for a given output document path. |
| `canonical-page-url` | Absolute canonical URL for a document path. |
| `query-backlinks` | The raw backlink records behind `backlinks()`. |

### Syndication & SEO

| Name | Purpose |
| :--- | :--- |
| `sitemap-xml` | Render `sitemap.xml`. |
| `robots-txt` | Render `robots.txt` pointing at the sitemap. |
| `rss-xml` | Render RSS 2.0. |
| `atom-xml` | Render Atom 1.0. |
| `content-to-feed-html` | Semantic-HTML body for full-text feeds. |
| `render-seo-meta` | OpenGraph / Google Scholar `<meta>` emission. |

### Text utilities

| Name | Purpose |
| :--- | :--- |
| `to-plain-text` | Strip markup to plain text. |
| `count-words` | Word count of a content tree. |
| `estimate-reading-minutes` | Reading-time estimate from a word count. |
| `word-hint` | Prose word-count hint used by `htm`. |
| `short-hash` | 32-bit FNV-1a content hash for `?v=` cache keys. |

### Tree traversal

| Name | Purpose |
| :--- | :--- |
| `find-content` | First matching node. |
| `any-content` | Does any node match? |
| `collect-content` | All matching nodes. |
| `map-containers` | Rebuild the tree, short-circuiting subtrees. |

## Blog preset — `#import "@preview/thyme:<v>": blog` then `#import blog: *`

The preset re-exports everything above, plus:

### Site & posts

| Name | Purpose |
| :--- | :--- |
| `site` (`blog.site`) | Bundler with tags, feeds, post lists, sidenotes, and the monochrome theme. |
| `post` | One blog post (`post(path(...))` or a literal body). |
| `post-asset` | Per-post asset (alias of `page-asset`). |
| `post-nav` | Chronological previous/next navigation. |
| `post-list` | Rendered list of posts. |
| `tag-cloud` | Live tag cloud; `/tags/` archives are emitted by `site`. |
| `toc` | Table of contents for the current document. |

### Theme

| Name | Purpose |
| :--- | :--- |
| `default-theme` | The `oklch(L, 0, 0deg)` monochrome palette and font stacks. |
| `resolve-theme` | Merge a partial `theme` override onto `default-theme`. |
| `active-theme` | The theme currently in effect for the enclosing document. |
| `css-oklch` | Convert a Typst colour to a CSS `oklch(...)` string. |
| `css-hex` | Convert a Typst colour to lowercase `#rrggbb` (needed for `theme-color`). |
| `stylesheet-css` | The rendered preset stylesheet as a string. |
| `stylesheet-href` | Content-addressed `?v=<hash>` stylesheet URL. |
| `stylesheet-asset-path` | Bundle path of the stylesheet (`css/style.css`). |
| `theme-override-css` | Per-document `:root` override block. |
| `default-woff2-files` | The bundled font file list, for self-hosting. |

### Notes & margin material

| Name | Purpose |
| :--- | :--- |
| `sidenote` / `sn` | Right-margin sidenote with a numbered reference. |
| `marginnote` / `mn` | Unnumbered margin note. |
| `mcite` | Margin bibliography citation. |
| `container` | The underlying margin container. |

### Blocks

| Name | Purpose |
| :--- | :--- |
| `callout`, `note-box`, `tip-box`, `warning-box`, `important-box` | Reader-Mode-safe callouts. |
| `sbox` | Generic boxed block. |
| `codeblock` | Code block with copy affordance. |
| `definition`, `theorem`, `lemma`, `proposition`, `corollary`, `example`, `recipe`, `remark`, `proof` | Academic environments. |
| `epigraph` | Pull quote. |
| `diagram` | Figure wrapper with `invert-dark`. |
| `wide` | Break out of the measure into the margin. |
| `kbd`, `hr`, `links` | Inline utilities (`links(direction: "row" \| "column")`). |

### Tables

| Name | Purpose |
| :--- | :--- |
| `tablem`, `three-line-table`, `grid-table`, `zebraw` | Table styles; `zebraw` is the preset default. |

### Re-exported upstream packages

`checklist` (cheq), `showybox`, `zebraw-init`, `zebraw-themes`.
