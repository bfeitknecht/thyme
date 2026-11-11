# Release checklist: `@preview/thyme:0.1.0` to Typst Universe

The pipeline is already wired. This file lists the actions to take.
The current blocker is that `@preview/syndicate:0.1.0` is not live on Typst Universe yet.

Thyme depends on `bfeitknecht/syndicate` for XML, Atom, RSS and sitemap encoding. That
package must reach Typst Universe before thyme, because thyme imports it as
`@preview/syndicate`. The version is `0.1.0` everywhere (`typst.toml`, README, template,
examples, tests, `docs/manual.typ`), so **you do not need to run `just bump`**. Tag
`v0.1.0` directly.

---

## 0. Publish syndicate, then wait until it resolves

Two releases are needed, and syndicate comes first:

1. Publish `@preview/syndicate:0.1.0` through the PR flow in `bfeitknecht/syndicate`.
2. Confirm that `@preview/syndicate:0.1.0` resolves from a clean package cache:

```sh
rm -rf "$HOME/.local/share/typst/packages/preview/syndicate"   # drop any local copy
typst query @preview/syndicate:0.1.0 --field version            # should print 0.1.0
```

If the query fails, stop. All later steps fail too.

## 1. Drop the vendored dependency

```sh
rm -rf vendor
```

Also delete the TODO at the top of `src/seo.typ` (lines 5–6) that asks for exactly this, and
drop the `vendor/*` glob from `_link-pkg` in the `justfile`. That glob is the last reference to
vendoring in the repository. No other change is needed: `just release` builds the payload from
`typst.toml`, and `typst-package-check` rejects an archive whose imports cannot resolve.

`vendor/syndicate/` is a verbatim copy of `lib.typ`, `src/`, `typst.toml`, `LICENSE` and
`README.md` from `bfeitknecht/syndicate`. If that package changes before release, copy the
files again rather than editing them here.

## 2. Re-verify against Universe without the local copy

```sh
just check          # all 3 bundles, unit tests and PDFs; read-only
just fmt --check
just lint
```

`just check` matters more here. After you delete `vendor/`, each `@preview/*` import resolves
through the real package cache. This build is the first proof that the published dependency
graph works.

## 3. Confirm the two repo settings

Neither is visible to the agent token — check them yourself:

- **Secret** `UNIVERSE_TOKEN` — fine-grained PAT with `Contents: read and write` on
  `bfeitknecht/packages` and `Pull requests: read and write` on `typst/packages`.
- **Variable** `UNIVERSE_SUBMIT` — set to `true`. It gates the `universe-pr` job and is
  currently unset/false, which means a tag today would publish the GitHub Release and
  silently skip the Universe PR.

The fork already exists (`bfeitknecht/packages`, confirmed fork of `typst/packages`) and
there is no existing `thyme-*` branch or open submission PR on it, so you start clean.

## 4. Validate before tagging

`release.yaml` has never executed. Exercise it without publishing anything:

```sh
just release v0.1.0 --check    # tag, version and CHANGELOG agree; nothing written
just release --notes           # the exact section CI will publish
```

`--check` covers the validation half of the workflow. If it passes and `--notes` reads correctly,
the GitHub API calls are the only untested part. A rehearsal tag is not possible, because
`just release` requires the tag to equal the version in `typst.toml` and refuses a `-rc.1`. Run
both commands before you tag. A workflow error is cheaper to find now.

## 5. Cut the release

`just release` takes one argument, the tag, and prompts for the commit message. It falls back to
the tag when stdin is not a tty, so it is safe to call from a script:

```sh
just release v0.1.0
```

It runs the gate (`just check`, `just fmt --check`, `just lint`), rebuilds `docs/manual.pdf` and
`thumbnail.png`, stages `dist/universe/`, then commits, tags and pushes. Do not replace this step
with a manual `git tag`, or the tag carries whatever stale artefacts were last committed.

## 6. Shepherd the upstream PR

`release.yaml` re-stages the payload at the tagged commit, runs `typst-package-check`, pushes
branch `thyme-0.1.0` to your fork, and opens a **draft** PR on `typst/packages`.

- Review the diff on the upstream PR. It must contain `src/`, `template/`, `typst.toml`,
  `README.md`, `LICENSE` and `thumbnail.png`. It must also contain `docs/manual.pdf`,
  `assets/` and `examples/`, which the `exclude` list in `typst.toml` keeps out of the compiler
  archive.
- Confirm upstream CI is green, then mark it **Ready for review**.
- Before merging, check the Universe preview page renders the template and that the
  thumbnail looks right.

## 7. Then unfreeze the downstreams

Only after `@preview/thyme:0.1.0` resolves from a clean cache. `glob` and `apex` both import
`@preview/thyme:0.1.0`, and `apex` also vendors a copy:

```sh
# glob: already imports @preview/thyme:0.1.0 from Universe; nothing to change
# apex: drop the vendored snapshot and resolve from Universe
rm -rf apex/ssg/vendor/thyme
```

`apex` needs its `just packages` recipe and the two `vendor/` copies in its `Dockerfile` edited
in the same change, or the build breaks.

Pin the exact version and let their CI hold it. The README's *Stability & Versioning*
section is the contract to hand to anyone downstream.

---

## Background notes

- **Payload size is fine.** Staged payload is 2.5 MB total, ~1.1 MB of it the compiler
  archive. `thumbnail.png` is 772 KB.
- **`docs/manual.pdf` is regenerated by `just release` before it commits**, not by `check`
  and not by CI: `check` is read-only, so the fresh manual reaches the tag as a normal commit
  and the GitHub Release attaches exactly what was tagged.
- **`docs/manual.pdf` rebuilds reproducibly** (`SOURCE_DATE_EPOCH=0`), so repeated builds are
  byte-identical.
- **`compiler = "0.15.1"`** while 0.15.2 is current. Not a blocker; bump deliberately if
  you want it, since CI installs exactly that version.
- **Template fonts.** The template references STIX Two / Commit Mono via CDN `@font-face`
  for HTML, but the paged Universe preview may fall back if those fonts are absent from
  their renderer. Cosmetic only — check it in step 6.
- **`[Unreleased]` is already folded into `[0.1.0]`** (done, dated 2026-11-09). This
  mattered because the release notes are the `## [0.1.0]` section of `CHANGELOG.md`:
  before folding, a `v0.1.0` tag would have published the original `[0.1.0]` body and
  silently omitted the `theme-color`, `robots.txt`, `shell-theme` and CI fixes — i.e. a
  release note that dropped its own headline fixes. Verified the extracted notes now
  contain all four. Keep `[Unreleased]` empty until the next cycle.
- **The notes are extracted by `just release`, not by a workflow step.** `just release --notes`
  and the CI publish step run the same code path, and it requires the section to be dated
  (`## [0.1.0] - YYYY-MM-DD`) and non-empty. A missing or empty section aborts before anything
  is published — it never falls back to a placeholder. Preview with `just release --notes`;
  do not read the CHANGELOG by eye and assume CI agrees.
- **The formatter is pinned to `typstyle` 0.15.1.** `just fmt --check` runs as its own CI
  job; if you bump the pin, run `just fmt` and commit the reformat in the same change, or
  `Format` goes red for the whole tree.
- **Never re-point an existing tag at new commits.** `actions/checkout` uses
  `inputs.tag || github.ref`, and `github.ref` for a tag push is the tag. If you delete and
  re-push a tag after amending the release commit, `universe-pr` can stage the *old* tree
  and open a PR that does not match the real release. Cut a fresh version instead.
