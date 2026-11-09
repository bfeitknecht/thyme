# Release checklist — `@preview/thyme:0.1.0` → Typst Universe

Everything below is wired already; this is the sequence of actions, not new engineering.
Current blocker is **only** `@preview/exemel:0.3.0` not being live on Universe yet.

Status at time of writing: `wensimehrp/exemel` PR #1 is still `OPEN`. The version is
`0.1.0` everywhere (`typst.toml`, README, template, examples, tests, `docs/manual.typ`),
so **no `just bump` is needed** — tag `v0.1.0` directly.

---

## 0. Wait for exemel to be *live*, not just merged

Three distinct events, in this order — do not conflate them:

1. Upstream `wensimehrp/exemel` PR #1 merged.
2. A PR adding `packages/preview/exemel/0.3.0` merged into `typst/packages`.
3. `@preview/exemel:0.3.0` actually resolves from a clean package cache.

Confirm (3) is really true before proceeding:

```sh
rm -rf "$HOME/.local/share/typst/packages/preview/exemel"   # drop any local copy
typst query @preview/exemel:0.3.0 --field version            # should print 0.3.0
```

If that fails, stop — everything downstream fails too.

## 1. Drop the vendored dependency

```sh
rm -rf vendor
```

Also delete the TODO at the top of `src/seo.typ` (lines 5–6) that asks for exactly this.

Guard rails that will make you do this anyway, which is the point of them:
`scripts/stage-universe.sh` refuses to stage while `vendor/*/typst.toml` exists, and the
`universe-pr` CI job fails the same check.

## 2. Re-verify against Universe, with no local safety net

```sh
just check          # all 3 bundles, unit tests, PDFs, staging dry run
just fmt-check
just lint
just docs
```

`just check` matters more now than usual: with `vendor/` gone, every `@preview/*` import
resolves through the real package cache, so this is the first build that proves the
published dependency graph works.

## 3. Confirm the two repo settings

Neither is visible to the agent token — check them yourself:

- **Secret** `UNIVERSE_TOKEN` — fine-grained PAT with `Contents: read and write` on
  `bfeitknecht/packages` and `Pull requests: read and write` on `typst/packages`.
- **Variable** `UNIVERSE_SUBMIT` — set to `true`. It gates the `universe-pr` job and is
  currently unset/false, which means a tag today would publish the GitHub Release and
  silently skip the Universe PR.

The fork already exists (`bfeitknecht/packages`, confirmed fork of `typst/packages`) and
there is no existing `thyme-*` branch or open submission PR on it, so you start clean.

## 4. Dry-run the release path first

`release.yaml` has never executed. Do one throwaway tag to exercise it before the real one:

```sh
just release v0.1.0-rc.1 "Dry run for release pipeline"
```

Expect: `verify` → `github-release` → `universe-pr` (this second tag is real, so it *will*
open a draft PR; that is the test). Then delete the tag, or just supersede it.

Cost of skipping this: if anything in the workflow is wrong, you find out while the real
tag is already public.

## 5. Cut the release

`just release` prompts when arguments are missing, which hangs in a non-tty. Pass both:

```sh
just release v0.1.0 "Initial release v0.1.0"
```

It runs `just check`, `just fmt-check`, `just lint`, then tags, pushes, and triggers
`release.yaml`.

## 6. Shepherd the upstream PR

`release.yaml` stages the payload, runs `typst-package-check`, pushes branch
`thyme-0.1.0` to your fork, and opens a **draft** PR on `typst/packages`.

- Review the diff on the upstream PR — it should contain `src/`, `template/`,
  `typst.toml`, `README.md`, `LICENSE`, `thumbnail.png`, plus `docs/manual.pdf` and
  `assets/`/`examples/` that `typst.toml`'s `exclude` keeps out of the compiler archive.
- Confirm upstream CI is green, then mark it **Ready for review**.
- Before merging, check the Universe preview page renders the template and that the
  thumbnail looks right.

## 7. Then unfreeze the downstreams

Only after `@preview/thyme:0.1.0` resolves from a clean cache:

```sh
# glob / apex
rm -rf vendor
# switch imports to @preview/thyme:0.1.0 at the version you just published
```

Pin the exact version and let their CI hold it. The README's *Stability & Versioning*
section is the contract to hand to anyone downstream.

---

## Things worth knowing, not blocking

- **Payload size is fine.** Staged payload is 2.5 MB total, ~1.1 MB of it the compiler
  archive. `thumbnail.png` is 772 KB.
- **`docs/manual.pdf` is regenerated in CI before staging**, so the Universe payload and
  the GitHub Release always get a fresh manual even if the committed copy lags.
- **`just docs` is now reproducible** (`SOURCE_DATE_EPOCH=0`), so repeated builds are
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
- **The notes step now fails instead of guessing.** Extraction lives in
  `scripts/changelog.py`; a missing, empty, undated, or subsection-less `## [<version>]`
  section aborts the run before anything is published. To preview the notes without
  tagging, run `python3 scripts/changelog.py notes 0.1.0`, and to check them
  `python3 scripts/changelog.py check 0.1.0 v0.1.0`.
- **The formatter is pinned to `typstyle` 0.15.1.** `just check` runs in CI after
  `just fmt-check`; if you bump the pin, run `just fmt` and commit the reformat in the
  same change, or `Format` goes red for the whole tree.
- **Never re-point an existing tag at new commits.** `actions/checkout` uses
  `inputs.tag || github.ref`, and `github.ref` for a tag push is the tag. If you delete and
  re-push a tag after amending the release commit, `universe-pr` can stage the *old* tree
  and open a PR that does not match the real release. Cut a fresh version instead.
