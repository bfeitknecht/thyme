// Unit & regression tests for `@preview/thyme` and `@preview/exemel`.
#import "@preview/thyme:0.1.0": *
#import blog: *
#import "../src/paths.typ": heading-anchor-id
#import "../src/htm.typ": _tokenize-htm
#import "../src/text.typ": query-body-words
#import "../src/blog/theme.typ": (
  css-hex, default-woff2-files, stylesheet-css, stylesheet-href,
  theme-override-css,
)
#import "../src/blog/notes.typ": is-sidenote-link
#import "@preview/exemel:0.3.0": format-rfc3339, rss-encode, rss-post

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
#assert.eq(css-hex(default-theme.paper-light), css-hex(
  default-theme.paper-light,
))
#assert.eq(css-hex(default-theme.text-light).len(), 7)

// `theme-color` must follow the *active* theme, not a pinned hex. A preset that resolves
// its own theme and then drops it on the way to the shell would emit the default here.
#let _probe-theme = (
  default-theme
    + (paper-light: oklch(50%, 0, 0deg), paper-dark: oklch(30%, 0, 0deg))
)
#assert.eq(css-hex(_probe-theme.paper-light), "#636363")
#assert.eq(css-hex(_probe-theme.paper-dark), "#2e2e2e")
#assert.ne(css-hex(_probe-theme.paper-light), css-hex(
  default-theme.paper-light,
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

// 5. `exemel` RFC 3339, `smartquote` preservation, & RSS `updated: auto` `<lastBuildDate>` inference
#let dt = datetime(
  year: 2026,
  month: 10,
  day: 30,
  hour: 14,
  minute: 5,
  second: 0,
)
#assert.eq(format-rfc3339(dt), "2026-10-30T14:05:00Z")
#assert.eq(format-rfc3339(dt, tz: "+01:00"), "2026-10-30T14:05:00+01:00")
#assert.eq(format-rfc3339(dt, tz: "+0200"), "2026-10-30T14:05:00+02:00")
#let rss-str = rss-encode(
  title: [Hilbert's "Notes"],
  site-link: "https://example.org/",
  updated: auto,
  tz: "+0100",
  posts: (
    rss-post(
      [Noether's Ring],
      link: "https://example.org/p/",
      is-permalink: false,
      published: dt,
      tz: "+0100",
    ),
  ),
)
#assert(rss-str.contains("Hilbert&apos;s &quot;Notes&quot;"))
#assert(rss-str.contains("Noether&apos;s Ring"))
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
//    and `htm` / `h` handle empty elements, `<pre>` whitespace, entities, & optional closes
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

#[#metadata(none)<thyme-body-start>]
#h("div.empty-box")
#h("p.prose-h")[Three hyperscript words]
#htm("<div class=\"empty-htm\"></div>")
#htm("<pre>line 1\n  indented line 2</pre>")
#htm("<ul><li>first<li>second &#8212; &#x2026; &hellip;</ul>")
#htm("<time datetime=\"2026-10-30\">Oct</time>")
#htm("<button disabled=\"false\" data-ok=\"true\">btn</button>")
#tr(
  en: [Primary branch],
  de: [Sekundärzweig #sidenote[Extra German sidenote words that must not inflate English count]],
)
#[#metadata(none)<thyme-body-end>]
#context {
  let hinted = query-body-words(0)
  // `h("p.prose-h")` (3) + `htm("<ul>...")` ("first"=1 + "second"=1) + `htm("<time>...")` ("Oct"=1) + `htm("<button>...")` ("btn"=1) = 7;
  // `<pre>` and secondary `de` `#sidenote[...]` contribute 0!
  if target() == "html" {
    assert.eq(hinted, 7)
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
  keeping $F(e)$ and $F(d^*)$ crisp · $ℝ^+$, $F(a / b)$, $F(union.sq.big_(n >= 0) d_n)$, $lr((e))$
]
#smallcaps[Ada Lovelace] · #smallcaps(all: true)[Theorem 1]

// 9. Paged PDF sidenote link sentinel (`is-sidenote-link`) prevents duplicate prose-baseline underlines
#assert(is-sidenote-link([#metadata("thyme-sn-link")1]))
#assert(not is-sidenote-link([ordinary link text]))

// 10. Multi-line `htm(...)` preserves inter-word spaces across line breaks adjacent to inline tags
#let parsed-inline = _tokenize-htm(
  "<p>\n  <a href=\"#a\">alpha</a>\n  or\n  <a href=\"#b\">beta</a>\n</p>",
  (:),
  (),
)
#assert.eq(
  parsed-inline.prose-pieces.map(to-plain-text).join(),
  "alpha or beta",
)
#htm(
  "<p class=\"multiline-inline\">\n  <a href=\"#a\">alpha</a>\n  or\n  <a href=\"#b\">beta</a>\n</p>",
)
