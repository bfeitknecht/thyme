// Unit & regression tests for `@preview/thyme` and `@preview/syndicate`.
#import "@preview/thyme:0.1.0": *
#import "@preview/thyme:0.1.0" as thyme
#import blog: *
// The internal helpers below are not part of the public surface, so the tests import
// them from their modules. That also means a test cannot pass just because a name
// happens to be re-exported.
#import "../src/paths.typ": canonical-page-url, heading-anchor-id, slugify, source-path-for
#import "../src/i18n.typ": assert-complete-translations, missing-translations, normalize-alternates
#import "../src/seo.typ": content-to-feed-html
#import "../src/text.typ": count-words, query-body-words, short-hash, to-plain-text, word-hint
#import "../src/tree.typ": any-content, map-containers
#import "../src/core.typ": with-html-math
#import "../src/blog/theme.typ": css-hex, default-woff2-files, stylesheet-css, stylesheet-href, theme-override-css
#import "../src/blog/notes.typ": is-sidenote-link
#import "@preview/syndicate:0.1.0": rfc3339, rss

// 1. Plain-text & word-count invariants (`smartquote`, fenced raw exclusion, `#tr(...)` primary branch)
#assert.eq(
  to-plain-text([Hilbert's "Basis" Theorem]),
  "Hilbert's \"Basis\" Theorem",
)
#assert.eq(count-words([Hilbert's don't state-of-the-art]), 3)
#assert.eq(
  count-words([
    Two words.
    ```rust
    fn ignored_code_tokens(a: i32, b: i32) -> i32 { a + b }
    ```
    Three more words.
  ]),
  5,
)
#assert.eq(
  count-words(tr(
    en: [Four English words here.],
    de: [Sechs deutsche Wörter stehen genau hier.],
  )),
  4,
)
#assert.eq(
  to-plain-text(tr(en: [Hello], de: [Hallo]), lang: "de"),
  "Hallo",
)

// 2. Full-byte content-addressed `short-hash` determinism & middle-byte sensitivity (26 KB)
#let h1 = short-hash("body { color: black; }")
#let h2 = short-hash("body { color: white; }")
#assert.eq(h1.len(), 8)
#assert.eq(h1, short-hash("body { color: black; }"))
#assert.ne(h1, h2)
#let chunk = "a" * 13000
#let big-a = chunk + "0" + chunk
#let big-b = chunk + "1" + chunk
#assert.eq(big-a.len(), 26001)
#assert.ne(short-hash(big-a), short-hash(big-b))

// 3. Slugify, heading anchor collision deduplication, source paths, canonical URLs, and hreflang normalization
#assert.eq(slugify([`*glob?` — Notes & Proofs!]), "glob-notes-proofs")
#assert.eq(heading-anchor-id(heading[§]), "section")
#let h-ex = heading[Example]
#assert.eq(heading-anchor-id(h-ex, prior-headings: ()), "example")
#assert.eq(heading-anchor-id(h-ex, prior-headings: (h-ex,)), "example-2")
#assert.eq(heading-anchor-id(h-ex, prior-headings: (h-ex, h-ex)), "example-3")

// `before()` is inclusive, so in a real document a heading is itself present in
// the `prior-headings` list its callers derive. It must not be suffixed as a
// duplicate of itself (the regression suffixed every heading with `-2`).
#show heading: it => {
  let priors = query(heading).filter(h => h.location() == it.location())
  assert.eq(heading-anchor-id(it, prior-headings: priors), "probe")
  it
}

= Probe

// `css-hex` must emit a well-formed lowercase #rrggbb for any theme colour.
#assert.eq(css-hex(rgb("#f2f2f2")), "#f2f2f2")
#assert.eq(css-hex(rgb("#000000")), "#000000")
#assert.eq(css-hex(theme-default.paper-light), css-hex(
  theme-default.paper-light,
))
#assert.eq(css-hex(theme-default.text-light).len(), 7)

// `theme-color` must follow the *active* theme, not a pinned hex. A preset that resolves
// its own theme and then drops it on the way to the shell would emit the default here.
#let _probe-theme = (
  theme-default + (paper-light: oklch(50%, 0, 0deg), paper-dark: oklch(30%, 0, 0deg))
)
#assert.eq(css-hex(_probe-theme.paper-light), "#636363")
#assert.eq(css-hex(_probe-theme.paper-dark), "#2e2e2e")
#assert.ne(css-hex(_probe-theme.paper-light), css-hex(
  theme-default.paper-light,
))

// `robots.txt` is a documented, exported feature; make sure it is actually emitted and
// points at the sitemap (it was exported but never called for a while).
#let _robots = robots-txt(
  site-url: "https://example.org",
  sitemap-path: "sitemap.xml",
)
#assert.eq(
  _robots,
  "User-agent: *\nAllow: /\n\nSitemap: https://example.org/sitemap.xml\n",
)
#assert.eq(
  robots-txt(site-url: "https://example.org/", sitemap-path: none),
  "User-agent: *\nAllow: /\n",
)

#assert.eq(source-path-for("posts/foo/index.html"), "posts/foo.typ")
#assert.eq(
  canonical-page-url("https://blog.example.org", "posts/foo/index.html"),
  "https://blog.example.org/posts/foo/",
)
#let alts = normalize-alternates(
  (de: "/de/posts/foo/", fr: "https://fr.example.org/foo/"),
  site-url: "https://example.org",
)
#assert.eq(alts.len(), 2)
#assert.eq(alts.at(0), (
  hreflang: "de",
  href: "https://example.org/de/posts/foo/",
))
#assert.eq(alts.at(1), (hreflang: "fr", href: "https://fr.example.org/foo/"))

// 4. Full-HTML feed serializer (`content-to-feed-html` with `label-urls` + `table`)
#let feed-frag = content-to-feed-html(
  [
    = First Section
    Hilbert's ring $R$ with `code`, #link("posts/bar/")[rel link], and #link(<about>)[About].
    - alpha
    - beta
    #table(
      columns: 2,
      table.header([Op], [Complexity]),
      [Lookup], [$O(1)$],
    )
    #theorem[Basis][If $R$ is Noetherian, so is $R[x]$.]
    #proof[By induction.]
  ],
  site-url: "https://notes.example.org",
  doc-path: "index.html",
  label-urls: (about: "https://notes.example.org/about/"),
)
#assert(feed-frag.contains("<h2>First Section</h2>"))
#assert(feed-frag.contains("Hilbert’s ring"))
#assert(
  feed-frag.contains(
    "<a href=\"https://notes.example.org/posts/bar/\">rel link</a>",
  ),
)
#assert(
  feed-frag.contains("<a href=\"https://notes.example.org/about/\">About</a>"),
)
#assert(feed-frag.contains("<ul><li>alpha</li><li>beta</li></ul>"))
#assert(
  feed-frag.contains(
    "<table><thead><tr><th>Op</th><th>Complexity</th></tr></thead><tbody><tr><td>Lookup</td><td><code>O(1)</code></td></tr></tbody></table>",
  ),
)
#assert(feed-frag.contains("<strong>Theorem.</strong>"))
#assert(feed-frag.contains("<p>◻</p>"))

// 5. `syndicate` RFC 3339, `smartquote` preservation, & RSS `updated: auto` `<lastBuildDate>` inference
#let dt = datetime(
  year: 2026,
  month: 10,
  day: 30,
  hour: 14,
  minute: 5,
  second: 0,
)
#assert.eq(rfc3339(dt), "2026-10-30T14:05:00Z")
#assert.eq(rfc3339(dt, tz: "+01:00"), "2026-10-30T14:05:00+01:00")
#assert.eq(rfc3339(dt, tz: "+0200"), "2026-10-30T14:05:00+02:00")
#let rss-str = rss.feed(
  title: [Hilbert's "Notes"],
  link: "https://example.org/",
  description: "Notes",
  updated: auto,
  tz: "+01:00",
  items: (
    rss.item(
      [Noether's Ring],
      link: "https://example.org/p/",
      guid: "https://example.org/p/",
      permalink: false,
      published: dt,
    ),
  ),
)
// `syndicate` escapes only `&` and `<` in text; quotes stay literal (valid XML).
#assert(rss-str.contains("Hilbert's \"Notes\""))
#assert(rss-str.contains("Noether's Ring"))
#assert(rss-str.contains("+0100</lastBuildDate>"))
#assert(rss-str.contains("+0100</pubDate>"))
#assert(rss-str.contains("isPermaLink=\"false\""))

// 6. AST walker container preservation (`map-containers`) & per-post theme override CSS
#let orig = block[Hello *world*]
#let untouched = map-containers(orig, _ => auto)
#assert.eq(untouched, orig)
#let override-css = theme-override-css((paper-light: oklch(97%, 0, 0deg)))
#assert(override-css.contains(":root {") and override-css.contains("oklch(97%"))

// 7. Paged PDF `#tr(...)` honors `set text(lang: "de")`, secondary `#tr` skips `word-hint`,
//    and native `html.*` constructors are left alone by the engine
#{
  set text(lang: "de")
  context {
    if target() == "paged" {
      let w-tr = measure(tr(
        en: [HI],
        de: [GERMAN_BRANCH_ACTIVE_LONG_STRING],
      )).width
      let w-en = measure([HI]).width
      assert(w-tr > w-en * 4)
    }
  }
  [#tr(en: [ENGLISH_BRANCH], de: [GERMAN_BRANCH_ACTIVE])]
}

// Component word hints. `word-hint` exists for markup rendered inside a `context`
// closure, where `count-words` cannot see the text. Native `html.*` content is not in
// that position, so it carries no hint and must not inflate the count either.
// An empty native element must keep its explicit open/close pair: `typst` renders
// `html.elem("div", attrs: ())` with no content as `<div class="..."></div>`, and the
// engine must not collapse it or drop it.
// `html.*` exists only in the HTML target, so the body is built inside a `context` that
// checks `target()`. The PDF compile of this file must not reference it.
#[#metadata(none)<thyme-body-start>]
#context {
  if target() == "html" {
    // An empty native element keeps its explicit open/close pair. `typst` renders
    // `html.elem("div", attrs: ())` with no content as `<div class="..."></div>`, and the
    // engine must not collapse it or drop it.
    html.elem("div", attrs: (class: "empty-box"))
    html.elem("p", attrs: (class: "prose-h"), [Three native words])
    // A `<pre>` keeps its whitespace when its body is a `raw` value. Markup would
    // collapse the line break, which is the exporter's behaviour and not ours.
    html.elem("pre", raw("line 1\n  indented line 2"))
    html.elem("ul", {
      html.elem("li", [first])
      html.elem("li")[second \u{2014} \u{2026} \u{2026}]
    })
    html.elem("time", attrs: (datetime: "2026-10-30"), [Oct])
    html.elem("button", attrs: (disabled: "false", "data-ok": "true"), [btn])
  }
}
#sidenote[Word-hinted sidenote text]
#tr(
  en: [Primary branch],
  de: [Sekundärzweig #sidenote[Extra German sidenote words that must not inflate
      English count]],
)
#[#metadata(none)<thyme-body-end>]
#context {
  let hinted = query-body-words(0)
  // Only the English `#sidenote` emits a hint: "Word-hinted" + "sidenote" + "text" = 3.
  // The `de` branch is secondary, so it contributes 0, and native `html.*` content is
  // outside a `context` closure, so it contributes 0 as well.
  if target() == "html" {
    assert.eq(hinted, 3)
  }
}

// 8. Deterministic `@font-face` rules (zero `local(...)` shadowing, `font-base` + `font-version`
//    self-hosting), `with-html-math` AST normalizer, and OpenType small caps (`smcp` / `c2sc`)
#assert.eq(default-woff2-files.len(), 11)
#let cdn-css = stylesheet-css()
#assert(not cdn-css.contains("local("))
#assert(cdn-css.contains("commit-mono-latin-700-italic.woff2"))
#let self-css = stylesheet-css(theme: (
  font-base: "/fonts/",
  font-version: "2.13b171-1.143",
))
#assert(not self-css.contains("local(") and not self-css.contains("jsdelivr"))
#assert(self-css.contains("/fonts/STIXTwoText-Regular.woff2?v=2.13b171-1.143"))
#assert(self-css.contains("/fonts/STIXTwoMath-Regular.woff2?v=2.13b171-1.143"))
#assert(
  self-css.contains("/fonts/CommitMono-700-Italic.woff2?v=2.13b171-1.143"),
)
#assert.ne(
  stylesheet-href(theme: (font-base: "/fonts/", font-version: "1")),
  stylesheet-href(theme: (font-base: "/fonts/", font-version: "2")),
)

#with-html-math[
  keeping $F(e)$ and $F(d^*)$ crisp · $ℝ^+$, $F(a / b)$,
  $F(union.sq.big_(n >= 0) d_n)$, $lr((e))$
]
#smallcaps[Ada Lovelace] · #smallcaps(all: true)[Theorem 1]

// 9. Paged PDF sidenote link sentinel (`is-sidenote-link`) prevents duplicate prose-baseline underlines
#assert(is-sidenote-link([#metadata("thyme-sn-link")1]))
#assert(not is-sidenote-link([ordinary link text]))

// 10. Multi-line plain Typst content in a native element keeps its inter-word spaces
// across line breaks adjacent to inline tags. This is Typst's behaviour, and the point of
// the assertion is that `thyme` adds nothing that could disturb it.
#context {
  if target() == "html" {
    html.elem("p", attrs: (class: "multiline-inline"), [
      #link("https://example.org/alpha")[alpha]
      or
      #link("https://example.org/beta")[beta]
    ])
  }
}
#assert.eq(to-plain-text([alpha or beta]), "alpha or beta")

// 11. `robots` and `llms` are pass-through files. Nothing is generated, so the only
// contract is that a `path(...)` is copied byte for byte. `robots-txt` stays exported as a
// starting point for an author who wants one, and it must remain valid on its own terms.
#let robots = robots-txt(
  site-url: "https://e.org",
  sitemap-path: "sitemap.xml",
)
#assert(robots.starts-with("User-agent: *"), message: robots)
#assert(robots.contains("Sitemap: https://e.org/sitemap.xml"), message: robots)
// A trailing slash on the site URL must not produce a doubled slash in the sitemap line.
#assert(
  not robots-txt(
    site-url: "https://e.org/",
    sitemap-path: "/sitemap.xml",
  ).contains("//sitemap.xml"),
)
// With no sitemap there is no `Sitemap:` line, rather than an empty one.
#assert(
  not robots-txt(site-url: "https://e.org", sitemap-path: none).contains(
    "Sitemap:",
  ),
)

// 12. `#tr(...)` completeness. A page that declares several languages must translate every
// block, or the language switcher offers a language that renders as a gap. Two languages make
// a missing branch obvious; six make four empty strings in a long post easy to ship.
#let complete-body = [
  #tr(en: [All], de: [Alle], fr: [Tous])
]
// Nested inside a block so the test also proves the scan descends into containers.
#let partial-body = [
  #block[#tr(en: [Partial], de: [Teilweise])]
]
// A fully translated page reports no gaps.
#assert.eq(missing-translations(complete-body, ("en", "de", "fr")).len(), 0)
// A block missing `fr` is reported once, with the missing code named.
#assert.eq(missing-translations(partial-body, ("en", "de", "fr")).len(), 1)
#assert(
  missing-translations(partial-body, ("en", "de", "fr")).first().contains("`fr`"),
)
// A single-language page is never a gap, whatever the block covers.
#assert.eq(missing-translations(partial-body, ("en",)).len(), 0)
#assert.eq(missing-translations(partial-body, ()).len(), 0)
// The guard passes a complete page and panics on an incomplete one.
#assert-complete-translations(complete-body, ("en", "de", "fr"))

// 13. The public surface is a chosen list, so its size is pinned. A new export is a
// deliberate edit to this assertion and to `docs/api.md`, not a side effect of adding a
// helper that `site` happens to call.
// 8 keys: the 7 public names plus `blog`, which is the preset namespace itself.
#assert.eq(dictionary(thyme).len(), 8)
#assert.eq(dictionary(thyme.blog).len(), 39)
// Names that used to be exported and are now internal. If one reappears, the surface has
// grown by accident.
#for name in (
  "slugify",
  "to-plain-text",
  "canonical-page-url",
  "sitemap-xml",
  "resolve-page-langs",
  "i18n-css",
  "count-words",
  "map-containers",
  "assert-complete-translations",
  "missing-translations",
  // Applied by the page shell rather than by the author.
  "with-html-math",
  // Removed outright: Typst's own `html.elem` covers them.
  "htm",
  "h",
  "enable-htm",
  // Replaced by a parameter on `webpage` / `post`.
  "page-asset",
  "post-asset",
  // Called by `blog.site` itself.
  "query-pages",
  "post-nav",
  "tag-cloud",
) {
  assert(
    name not in dictionary(thyme),
    message: name + " is exported again; it belongs to a module, not the public surface",
  )
}
