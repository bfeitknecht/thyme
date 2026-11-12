<!--
Thanks for submitting a package! Please read and follow the submission guidelines detailed in the repository's README and check the boxes below. Please name your PR as `name:version` of the submitted package.

If you want to make a PR for something other than a package submission, just delete all this and make a plain PR.
-->

I am submitting
- [x] a new package
- [ ] an update for a package

<!--
Please add a brief description of your package below and explain why you think it is useful to others. If this is an update, please briefly say what changed.
-->

Description: `thyme` builds static sites from Typst's native `bundle` and typed `html` targets, so the `typst` CLI alone compiles and serves a site — no wrapper CLI and no client-side JavaScript. Its core is zero-CSS: one import and `#show: site.with(..)` gives you a site, and you style it with your own stylesheet. A `blog` preset adds a monochrome scholarly theme with native MathML, right-margin sidenotes and citations, theorem and proof environments, and two-column print output. It emits `sitemap.xml`, `robots.txt`, Atom 1.0 and RSS 2.0 feeds, OpenGraph and Google Scholar Highwire metadata, and it keeps the Typst source of every page in the bundle so a reader can jump from a paragraph to the code that produced it. It is useful to anyone who wants a documentation site or blog written in Typst where the output is a plain directory of static files, and who would rather write content than configure a generator. The manual is at https://github.com/bfeitknecht/thyme/releases/download/v0.1.0/manual.pdf.

<!--
These things need to be checked for a new submission to be merged. If you're just submitting an update, you can delete the following section.
-->

I have read and followed the submission guidelines and, in particular, I
- [x] selected [a name](https://github.com/typst/packages/blob/main/docs/manifest.md#naming-rules) that isn't the most obvious or canonical name for what the package does
  - Explanation:
    > Thyme is a herb in the mint family, and the fifth-century BC physician Hippocrates
    > listed it as a medicinal plant.

    The name is a related but creative term: it does not describe Typst, sites,
    generation, or anything else the package does, so it cannot be confused with the
    canonical word for what it is. It is a short, pronounceable noun from a different
    domain, in the same spirit as a herb name for something that grows content from
    semantic markup.
- [x] added a [`typst.toml`](https://github.com/typst/packages/blob/main/docs/manifest.md#package-metadata) file with all required keys
- [x] added a [`README.md`](https://github.com/typst/packages/blob/main/docs/documentation.md) with documentation for my package
- [x] have chosen [a license](https://github.com/typst/packages/blob/main/docs/licensing.md) and added a `LICENSE` file or linked one in my `README.md`
- [x] tested my package locally on my system and it worked
- [x] [`exclude`d](https://github.com/typst/packages/blob/main/docs/tips.md#what-to-commit-what-to-exclude) PDFs or README images, if any, but not the LICENSE

<!--
The following box only needs to be checked for **template** submissions. If you're submitting a package that isn't a template, you can delete the following section. See the guidelines section about licenses in the README for more details.
-->
- [x] ensured that my package is licensed such that users can use and distribute the contents of its template directory without restriction, after modifying them through normal use.
