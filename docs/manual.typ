// thyme v0.1.0 — Package Reference Manual (generated from source doc-comments via @preview/tidy)
#import "@preview/tidy:0.4.3"
#import "@preview/thyme:0.1.0"
#import "@preview/thyme:0.1.0": *
#import blog: (
  checklist,
  default-theme,
  kbd,
  sidenote,
  wide,
  zebraw,
  zebraw-init,
)

#import "../src/blog/notes.typ": is-sidenote-link

#let t = default-theme
#let combined-scope = dictionary(thyme) + dictionary(thyme.blog)

#set document(
  title: "thyme — Package Reference Manual",
  author: "Basil Feitknecht",
)

#set page(
  paper: "a4",
  margin: (top: 20mm, bottom: 20mm, left: 18mm, right: 66mm),
  fill: t.paper-light,
  header: context {
    if here().page() > 1 {
      set text(font: t.mono-fonts, size: 7.5pt, fill: t.muted-light)
      [thyme v0.1.0 #h(1fr) Package Reference Manual]
      v(-0.45em)
      line(length: 100%, stroke: 0.45pt + t.border-light)
    }
  },
  footer: context {
    set text(font: t.mono-fonts, size: 7.5pt, fill: t.muted-light)
    line(length: 100%, stroke: 0.45pt + t.border-light)
    v(-0.35em)
    [https://github.com/bfeitknecht/thyme #h(1fr) #counter(page).display("1 / 1", both: true)]
  },
)

#set text(font: t.serif-fonts, size: 10pt, fill: t.text-light, lang: "en")
#set par(leading: 0.68em, spacing: 1.15em, justify: false)
#show math.equation: set text(font: t.math-fonts)
#show raw: set text(font: t.mono-fonts, size: 0.84em)
#show raw.where(block: false): box.with(
  fill: t.surface-1-light,
  stroke: 0.45pt + t.border-light,
  inset: (x: 0.3em, y: 0pt),
  outset: (y: 0.16em),
  radius: 2pt,
)
#show link: it => {
  if not is-sidenote-link(it.body) {
    underline(
      stroke: 0.5pt + t.muted-light,
      offset: 1.8pt,
      it,
    )
  } else {
    it
  }
}
#show: zebraw-init
#show: checklist.with(
  marker-map: (
    " ": move(dy: -0.08em, box(baseline: bottom, circle(radius: 0.22em, stroke: 0.65pt + t.muted-light))),
    "x": move(dy: -0.08em, box(baseline: bottom, circle(radius: 0.22em, stroke: 0.65pt + t.text-light, fill: t.text-light))),
  ),
)

#set heading(numbering: "1.1")
#show heading.where(level: 1): it => block(above: 1.9em, below: 0.9em, breakable: false, {
  if it.numbering != none {
    text(font: t.mono-fonts, size: 0.78em, weight: "regular", fill: t.muted-light, counter(heading).display("01"))
    h(0.55em)
  }
  show raw.where(block: false): r => text(font: t.mono-fonts, size: 0.86em, r.text)
  text(size: 1.38em, weight: "semibold", it.body)
  v(0.28em)
  line(length: 100%, stroke: 0.55pt + t.border-light)
})
#show heading.where(level: 2): it => block(above: 1.45em, below: 0.65em, breakable: false, {
  if it.numbering != none {
    text(font: t.mono-fonts, size: 0.78em, weight: "regular", fill: t.muted-light, counter(heading).display())
    h(0.5em)
  }
  show raw.where(block: false): r => text(font: t.mono-fonts, size: 0.88em, r.text)
  text(size: 1.12em, weight: "semibold", it.body)
})

// ─── Monochrome `tidy` Style ─────────────────────────────────────────────────

#let _show-type(tp, style-args: (:)) = {
  box(
    fill: t.surface-2-light,
    stroke: 0.45pt + t.border-light,
    inset: (x: 0.3em, y: 0.12em),
    radius: 2pt,
    text(font: t.mono-fonts, size: 7.4pt, fill: t.muted-light, tp),
  )
}

#let _show-parameter-list(fn, style-args) = {
  block(
    width: 100%,
    fill: t.surface-1-light,
    stroke: 0.5pt + t.border-light,
    inset: (x: 0.65em, y: 0.5em),
    radius: 2pt,
    breakable: false,
    {
      set text(font: t.mono-fonts, size: 8.2pt, fill: t.text-light)
      text(weight: "bold", fn.name)
      "("
      let inline-args = fn.args.len() <= 3
      if not inline-args and fn.args.len() > 0 { "\n  " }
      let items = ()
      for (name, info) in fn.args {
        if style-args.omit-private-parameters and name.starts-with("_") {
          continue
        }
        let def-part = if "default" in info {
          ": " + text(fill: t.muted-light, info.default)
        } else {
          ""
        }
        let target-lbl = label(style-args.label-prefix + fn.name + "." + name.trim("."))
        let linked-name = if style-args.enable-cross-references and info.at("description", default: "") != "" {
          link(target-lbl, name)
        } else {
          name
        }
        items.push(linked-name + def-part)
      }
      items.join(if inline-args { ", " } else { ",\n  " })
      if not inline-args and fn.args.len() > 0 { ",\n" }
      ")"
      if fn.return-types != none {
        h(0.45em)
        text(fill: t.muted-light)[->]
        h(0.35em)
        fn.return-types.map(tp => _show-type(tp)).join([ ])
      }
    },
  )
}

#let _show-parameter-block(
  name,
  types,
  content,
  style-args,
  show-default: false,
  default: none,
  function-name: none,
) = block(
  width: 100%,
  above: 0.48em,
  below: 0.48em,
  breakable: style-args.break-param-descriptions,
  {
    set par(leading: 0.56em, spacing: 0.55em)
    text(font: t.mono-fonts, size: 8.3pt, weight: "bold", fill: t.text-light, name)
    if function-name != none and style-args.enable-cross-references {
      [#box()#label(function-name + "." + name.trim("."))]
    }
    if types.len() > 0 {
      h(0.4em)
      types.map(tp => _show-type(tp)).join(h(0.22em))
    }
    if show-default {
      h(0.45em)
      text(font: t.mono-fonts, size: 7.6pt, fill: t.muted-light, "= " + default)
    }
    linebreak()
    pad(left: 0.9em, text(size: 9.2pt, content))
  },
)

#let _render-doc-example(raw-it) = {
  let code-str = raw-it.text.trim("\n")
  let preview = eval(code-str, mode: "markup", scope: combined-scope)
  block(
    width: 100%,
    above: 0.6em,
    below: 0.65em,
    breakable: false,
    stack(
      dir: ttb,
      spacing: 0pt,
      block(
        width: 100%,
        fill: t.surface-1-light,
        stroke: 0.5pt + t.border-light,
        inset: (x: 0.65em, y: 0.48em),
        radius: (top: 2pt, bottom: 0pt),
        raw(code-str, lang: "typ", block: true),
      ),
      block(
        width: 100%,
        fill: t.paper-light,
        stroke: (
          left: 0.5pt + t.border-light,
          right: 0.5pt + t.border-light,
          bottom: 0.5pt + t.border-light,
          top: none,
        ),
        inset: (x: 0.7em, y: 0.55em),
        radius: (top: 0pt, bottom: 2pt),
        preview,
      ),
    ),
  )
}

#let _show-function(fn, style-args) = block(
  width: 100%,
  above: 1.05em,
  below: 0.95em,
  stroke: (left: 1.3pt + t.frame-light),
  inset: (left: 0.85em, y: 0.1em),
  breakable: true,
  {
    show raw.where(lang: "example"): _render-doc-example
    _show-parameter-list(fn, style-args)
    if style-args.enable-cross-references {
      [#box()#label(style-args.label-prefix + fn.name + "()")]
    }
    if fn.description != "" {
      v(0.35em)
      tidy.utilities.eval-docstring(fn.description, style-args)
    }
    let param-blocks = ()
    for (name, info) in fn.args {
      if style-args.omit-private-parameters and name.starts-with("_") {
        continue
      }
      let desc = info.at("description", default: "")
      if desc == "" and style-args.omit-empty-param-descriptions {
        continue
      }
      param-blocks.push(_show-parameter-block(
        name,
        info.at("types", default: ()),
        tidy.utilities.eval-docstring(desc, style-args),
        style-args,
        show-default: "default" in info,
        default: info.at("default", default: none),
        function-name: style-args.label-prefix + fn.name,
      ))
    }
    if param-blocks.len() > 0 {
      v(0.4em)
      block(
        below: 0.25em,
        breakable: false,
        text(font: t.sans-fonts, size: 7.4pt, weight: "bold", tracking: 0.05em, fill: t.muted-light)[PARAMETERS.],
      )
      param-blocks.join()
    }
  },
)

#let _show-variable(var, style-args) = block(
  width: 100%,
  above: 1.0em,
  below: 0.9em,
  stroke: (left: 1.3pt + t.frame-light),
  inset: (left: 0.85em, y: 0.1em),
  breakable: true,
  {
    block(
      width: 100%,
      fill: t.surface-1-light,
      stroke: 0.5pt + t.border-light,
      inset: (x: 0.65em, y: 0.5em),
      radius: 2pt,
      breakable: false,
      {
        text(font: t.mono-fonts, size: 8.2pt, weight: "bold", fill: t.text-light, var.name)
        if style-args.enable-cross-references {
          [#box()#label(style-args.label-prefix + var.name)]
        }
        if "type" in var and var.type != none {
          h(0.5em)
          _show-type(var.type)
        }
      },
    )
    if var.description != "" {
      v(0.35em)
      tidy.utilities.eval-docstring(var.description, style-args)
    }
  },
)

#let thyme-tidy-style = (
  show-outline: (module-doc, style-args: (:)) => none,
  show-type: _show-type,
  show-parameter-list: _show-parameter-list,
  show-parameter-block: _show-parameter-block,
  show-function: _show-function,
  show-variable: _show-variable,
  show-reference: (lbl, name, style-args: none) => link(lbl, raw(name, lang: none)),
  show-example: (..args) => tidy.show-example.show-example(
    ..args,
    dir: ttb,
    scale-preview: 100%,
    layout: tidy.show-example.default-layout-example.with(
      dir: ttb,
      scale-preview: 100%,
      col-spacing: 0.45em,
      code-block: block.with(
        fill: t.surface-1-light,
        stroke: 0.5pt + t.border-light,
        inset: (x: 0.6em, y: 0.45em),
        radius: 2pt,
      ),
      preview-block: block.with(
        fill: t.paper-light,
        stroke: 0.5pt + t.border-light,
        inset: (x: 0.65em, y: 0.5em),
        radius: 2pt,
      ),
    ),
  ),
)

#let render-src-module(mod-path, prefix, omit-names: ()) = {
  let parsed = tidy.parse-module(
    read(mod-path),
    label-prefix: "thyme-" + prefix + "-",
    scope: combined-scope,
  )
  let filtered = if omit-names.len() > 0 {
    parsed + (
      functions: parsed.functions.filter(f => f.name not in omit-names),
      variables: parsed.variables.filter(v => v.name not in omit-names),
    )
  } else {
    parsed
  }
  tidy.show-module(
    filtered,
    style: thyme-tidy-style,
    show-module-name: false,
    show-outline: false,
    omit-private-definitions: true,
    omit-private-parameters: true,
    break-param-descriptions: true,
    sort-functions: none,
  )
}

// ─── Title Block ─────────────────────────────────────────────────────────────

#block(width: 100%, below: 1.5em, {
  text(font: t.mono-fonts, size: 2.2em, weight: "bold", tracking: -0.03em)[thyme]
  h(0.65em)
  text(font: t.mono-fonts, size: 0.9em, fill: t.muted-light)[v0.1.0 · Typst >= 0.15.1]
  v(0.35em)
  text(size: 1.14em, fill: t.muted-light, emph[
    Pure-Typst static site generator with typed hypertagged HTML, Tadi Web .typ source transparency, zero-JS CSS i18n, XML sitemaps & feeds, and a monochrome blog preset.
  ])
  v(0.75em)
  block(
    width: 100%,
    stroke: (top: 0.55pt + t.border-light, bottom: 0.55pt + t.border-light),
    inset: (y: 0.48em),
    {
      set text(font: t.mono-fonts, size: 8pt)
      grid(
        columns: (6.8em, 1fr),
        row-gutter: 0.34em,
        column-gutter: 0.9em,
        text(fill: t.muted-light)[core ssg], [`#import "@preview/thyme:0.1.0": *`],
        text(fill: t.muted-light)[blog preset], [`#import blog: *` or `site.with(preset: blog)`],
        text(fill: t.muted-light)[scaffold], [`typst init @preview/thyme:0.1.0 my-site`],
        text(fill: t.muted-light)[dev / build], [`typst watch --features html,bundle -f bundle site.typ dist`],
        text(fill: t.muted-light)[license], [`MIT` (`src/`) · `MIT-0` (`template/`, `examples/`)],
      )
    },
  )
})

#outline(title: none, indent: 1.1em, depth: 2)

= Two-Layer Architecture & Pure-Typst Workflow

`thyme` separates static-site orchestration from visual theming across two composable layers, driven exclusively by the standard `typst` CLI (`typst compile` and `typst watch`) without external wrapper CLIs or client-side JavaScript runtimes#sidenote[Typst `0.15.1`'s `typst watch -f bundle` includes a built-in live-reloading HTTP server (`--port`, `--no-reload`, `--no-serve`).]:

#v(1.4em)
#wide[
  #table(
    columns: (auto, auto, 1fr),
    stroke: (x, y) => (
      top: if y == 0 { 0.65pt + t.frame-light } else { 0.45pt + t.border-light },
      bottom: 0.5pt + t.border-light,
      left: none,
      right: none,
    ),
    inset: (x: 0.55em, y: 0.46em),
    fill: (_, y) => if y == 0 { t.surface-1-light } else { none },
    align: (left + horizon, left + horizon, left + horizon),
    table.header(
      text(font: t.sans-fonts, size: 7.8pt, weight: "bold")[LAYER],
      text(font: t.sans-fonts, size: 7.8pt, weight: "bold")[IMPORT],
      text(font: t.sans-fonts, size: 7.8pt, weight: "bold")[RESPONSIBILITIES],
    ),
    [Core SSG],
    [`#import "@preview/thyme:0.1.0": *`],
    [Unopinionated zero-CSS `site`, `webpage`, `mount(path(...))`, `raw-file`, `backlinks`, `htm` / `h` typed hypertagged HTML, `#tr(...)` zero-JS CSS i18n + `hreflang` alternates, sibling `.typ` source co-emission, `sitemap.xml`, `robots.txt`, OpenGraph/Scholar `<meta>`, and summary or full-HTML `rss.xml` / `atom.xml`.],
    [`blog` Preset],
    [`#import blog: *` / `preset: blog`],
    [Opinionated scholarly monochrome blog (`oklch` / `light-dark()` + 2-column `@media print`), _STIX Two_ + _Helvetica Neue_ + _Commit Mono_, `@preview/marge` sidenotes + `#mcite` margin citations, static `/tags/` archives, `#toc()`, `#post-nav()`, Obsidian `<dl>` frontmatter, theorem/proof boxes, `zebraw`, `tablem`, and `cheq`.],
  )
]

= Tadi Web `.typ` Sources & `sws.toml` Headers

When pages are mounted via Typst capability paths (`src: path("site.typ")`, `#mount(path("contact.typ"))`, `#post(path("posts/foo.typ"))`), `thyme` reads and co-emits the verbatim `.typ` source alongside each HTML page (`index.typ`, `contact.typ`, `posts/foo.typ`) and links it via `.typ` in the top utility bar. Configure your static server (such as `static-web-server`) so browsers render `.typ` inline as UTF-8 plaintext:

#zebraw(numbering: false)[
  ```toml
  [[advanced.headers]]
  source = "**/*.typ"
  headers = { Content-Type = "text/plain; charset=utf-8", Content-Disposition = "inline" }
  ```
]

= Core SSG Reference (`src/*.typ`)

== Site Bundler, Subpages & Raw Assets (`src/core.typ`)
#render-src-module(
  "../src/core.typ",
  "core",
  omit-names: (
    "normalize-assets",
    "extract-page-meta",
    "extract-page-assets",
    "extract-raw-files",
    "emit-bundle-asset",
    "extract-mounts",
    "transform-mounts",
    "lookup-source-href",
    "query-doc-tr-codes",
    "extract-first-h1",
    "render-top-bar",
    "render-core-shell",
    "resolve-core-mount",
  ),
)

== Typed Hypertagged HTML & Hyperscript (`src/htm.typ`)
#render-src-module("../src/htm.typ", "htm")

== Zero-JS Single-URL CSS i18n (`src/i18n.typ`)
#render-src-module("../src/i18n.typ", "i18n")

== Sitemap, `robots.txt` & Feeds (`src/seo.typ`)
#render-src-module("../src/seo.typ", "seo")

== URLs, Slugs, AST Traversal & Plain Text (`src/paths.typ`, `src/text.typ`, `src/tree.typ`)
#render-src-module("../src/paths.typ", "paths")
#render-src-module("../src/text.typ", "text")
#render-src-module("../src/tree.typ", "tree")

= `blog` Preset Reference (`src/blog/*.typ`)

== Blog Bundler (`src/blog/site.typ`)
#render-src-module("../src/blog/site.typ", "blog-site")

== Post Template (`src/blog/post.typ`)
#render-src-module("../src/blog/post.typ", "blog-post")

== Scholarly Environments & Components (`src/blog/components.typ`)
#render-src-module("../src/blog/components.typ", "blog-components")

== Right-Margin Sidenotes (`src/blog/notes.typ`)
#render-src-module("../src/blog/notes.typ", "blog-notes")

== Monochrome Theme & Fonts (`src/blog/theme.typ`)
#render-src-module("../src/blog/theme.typ", "blog-theme")
