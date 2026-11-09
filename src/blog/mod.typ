// Public exports of the `blog` scholarly monochrome blog preset inside `@preview/thyme`.
//
// Usage:
//   #import "@preview/thyme:0.1.0": *
//   #import blog: *
//   // or order-independently:
//   #show: blog.site.with(...)
//
// Generic core functions (`site`, `webpage`, `mount`, `file`, ...) are exported by
// `lib.typ` itself; this module only re-exports them so `#import blog: *` alone is
// enough to build a site. In Typst every top-level `#let`/`#import` of a file is part
// of that file's module, so the imports above are the public export surface.

// Upstream packages re-exported so `#import blog: *` matches the documented surface
// (the manual and examples rely on `checklist`, `showybox`, `zebraw-init`, ...).
#import "@preview/cheq:0.4.0": checklist
#import "@preview/showybox:2.0.4": showybox
#import "@preview/zebraw:0.6.3": (
  zebraw-init,
  zebraw-themes,
)

#import "../core.typ": (
  backlinks,
  file,
  mount,
  query-pages,
  route,
  webpage,
  with-html-math,
)

#import "theme.typ": (
  active-theme,
  build-stylesheet,
  build-theme-override-css,
  css-oklch,
  default-theme,
  default-woff2-files,
  resolve-theme,
  stylesheet-asset-path,
  stylesheet-href,
)

#import "notes.typ": (
  container,
  marginnote,
  mcite,
  mn,
  sidenote,
  sn,
)

#import "components.typ": (
  callout,
  codeblock,
  corollary,
  definition,
  diagram,
  epigraph,
  example,
  grid-table,
  hr,
  important-box,
  kbd,
  lemma,
  links,
  note-box,
  proof,
  proposition,
  recipe,
  remark,
  sbox,
  tablem,
  theorem,
  three-line-table,
  tip-box,
  toc,
  warning-box,
  wide,
  zebraw,
)

#import "post.typ": (
  post,
  post-asset,
  post-nav,
  query-all-posts,
)

#import "site.typ": (
  post-list,
  site,
  tag-cloud,
)

// Preset surface (imported above, hence re-exported by this module).
// - core engine: site, webpage, route, mount, file, query-pages, backlinks, with-html-math
// - theme: active-theme, build-stylesheet, build-theme-override-css, css-oklch,
//          default-theme, default-woff2-files, resolve-theme, stylesheet-asset-path, stylesheet-href
// - notes: container, marginnote, mcite, mn, sidenote, sn
// - components: callout, codeblock, ..., zebraw
// - posts: post, post-asset, post-nav, query-all-posts
// - listings: post-list, tag-cloud
