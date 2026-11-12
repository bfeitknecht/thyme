# `thyme` — Release & Full Rollout Scratchpad

> Local maintainer scratch file (excluded from the Typst Universe package archive via `typst.toml` `exclude`).
>
> **Actionable step-by-step sequence: [`docs/release-checklist.md`](docs/release-checklist.md).**
> This file is the broader rollout context (glob, apex, infra); that one is the shortlist.

## 1. End-to-End Rollout Checklist (`syndicate` → `thyme` → `glob` → `apex`)

### Step 1 — Publish `@preview/syndicate:0.1.0` on Typst Universe — **done**
- [x] Cut `syndicate` `v0.1.0` in [`bfeitknecht/syndicate`](https://github.com/bfeitknecht/syndicate) and open its `typst/packages` PR.
- [x] `syndicate:0.1.0` is merged into [`typst/packages`](https://github.com/typst/packages).

`syndicate` exists because the upstream `wensimehrp/exemel` maintainer declined the RSS 2.0 and
sitemap additions. Thyme no longer depends on `exemel`.

### Step 2 — Publish `bfeitknecht/thyme` & submit `@preview/thyme:0.1.0`

> **The release pipeline is already wired and gated.** Pushing a `v*.*.*` tag runs
> `.github/workflows/release.yaml`: `verify` (tag against `typst.toml` and `CHANGELOG.md`, then
> the full check suite), then `github-release` (GitHub Release with `docs/manual.pdf` attached),
> then `universe-pr` (stage, `typst-package-check`, push to the fork, open the Draft PR).
>
> `universe-pr` is **skipped unless the repository variable `UNIVERSE_SUBMIT` is `true`**. Set it
> when you are ready to publish. It must be a *variable* (`vars.UNIVERSE_SUBMIT`), because a secret
> cannot gate a job-level `if`.
>
> The PR into `typst/packages` cannot be opened by a fine-grained token, because the org restricts
> them. The job tries, and when it is refused it writes the compare link to its summary and exits
> 0. Opening that link is the last step of the submission.

- [ ] **Configure GitHub repo & Universe fork**
  - Create `bfeitknecht/thyme` on GitHub.
  - Fork `https://github.com/typst/packages` to `https://github.com/bfeitknecht/packages` (or set repo variable `UNIVERSE_REPO` if using another owner, host or fork).
  - Add repository secret `UNIVERSE_TOKEN` on `bfeitknecht/thyme` (fine-grained PAT with `Contents: Read and write` on `bfeitknecht/packages`). Do not add `typst/packages`; the org refuses it.
  - Set repository variable `UNIVERSE_SUBMIT` to `true` when you are ready to publish.
- [x] **Remove temporary `syndicate` vendoring once `syndicate:0.1.0` is live**
  - `vendor/` is deleted, the `// TODO` in `src/seo.typ` is gone, the `vendor/*` glob is out of
    `_link-pkg`, and `"/vendor/"` is out of `typst.toml`.
- [ ] **Verify & stage locally against live Typst Universe**
  ```sh
  just check
  ```
- [ ] **Cut `v0.1.0` & open the Universe PR**
  ```sh
  git init -b main
  git remote add origin git@github.com:bfeitknecht/thyme.git
  just release v0.1.0    # prompts for the commit message; falls back to the tag
  ```
  - Verify GitHub Actions (`release.yaml`) publishes the `v0.1.0` GitHub Release (with `docs/manual.pdf` attached), runs `typst-package-check`, pushes branch `thyme-0.1.0` to `bfeitknecht/packages`, and opens a **Draft PR** on `typst/packages`.
  - Review the Draft PR diff on `typst/packages`, confirm upstream CI is green, mark **Ready for review**, and wait for `@preview/thyme:0.1.0` to merge.

### Step 3 — Deploy `bfeitknecht/glob` (`blog.0xbf.ch`)
- [ ] **Move Kubernetes / Flux manifests into `bfeitknecht/infra`**
  - Copy `glob/infra/glob/` → `kubernetes/applications/glob/` in `bfeitknecht/infra`.
  - Append `glob/infra/applications-entry.yaml` to `kubernetes/cluster/applications.yaml` in `bfeitknecht/infra`.
  - Ensure the `dockerconfigjson` pull secret exists in namespace `glob` and `blog.0xbf.ch` DNS points to your ingress, then commit & push `bfeitknecht/infra`.
  - Clean the staging directories from `glob`:
    ```sh
    rm -rf infra public
      ```
- [ ] **Push & tag `bfeitknecht/glob` (once both `syndicate:0.1.0` and `thyme:0.1.0` are live on Universe)**
  ```sh
  just compile
  git init -b main
  git remote add origin git@github.com:bfeitknecht/glob.git
  just release v0.1.0 "Initial release"
  ```
  *(Triggers `.github/workflows/publish-image.yaml` via `bfeitknecht/infra`, pushing `ghcr.io/bfeitknecht/glob:latest` for Flux/Keel to deploy.)*

### Step 4 — Update `bfeitknecht/apex` (`0xbf.ch`)
- [ ] Copy the files from `apex/` into your `bfeitknecht/apex` checkout (`cv.pdf`, `age.txt`, and `pgp.txt` already match upstream; replace `cv.pdf` if updated).
- [ ] **Pin to Universe.** Imports resolve `@preview/thyme:0.1.0` from the
  real package cache. `apex` has no `vendor/` fallback, so this step is gated on Step 1 alone.
- [ ] *(Optional — Ratatui WASM TUI)* Pass `head: html.script(type: "module", src: "/boot.js")` inside `site.with(...)` in `site.typ` and copy the compiled WASM/`.js` assets into `/public/` in `Dockerfile`.
- [ ] **Compile & release**
  ```sh
  rm -rf public
  just compile
  just release v0.2.0 "Migrate static site to thyme"
  ```

---

## 2. Static Server `.typ` Inline Plaintext Recipe (`sws.toml`)

Browsers download `.typ` files unless the HTTP server sends `Content-Type: text/plain; charset=utf-8`. For `static-web-server` (`sws.toml` on Talos / Docker / K8s):

```toml
[[advanced.headers]]
source = "**/*.typ"
headers = { Content-Type = "text/plain; charset=utf-8", Content-Disposition = "inline" }
```

---

## 3. Deferred Post-`0.1.0` Roadmap Notes

- **Comments (deferred to `v0.2+`)**: Intentionally excluded from `0.1.0`. Never adopt GitHub-gatekept comment widgets (e.g. Giscus). Candidate directions when revisited: zero-JS `mailto:` reply links paired with curated static letter appendices, or Webmention/IndieWeb static build ingestion.
