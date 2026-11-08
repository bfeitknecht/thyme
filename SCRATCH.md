# `thyme` — Release & Full Rollout Scratchpad

> Local maintainer scratch file (excluded from the Typst Universe package archive via `typst.toml` `exclude`).

## 1. End-to-End Rollout Checklist (`exemel` → `thyme` → `glob` → `apex`)

### Step 1 — Wait for `@preview/exemel:0.3.0` on Typst Universe
- [ ] Merge the `exemel` `v0.3.0` PR (`sitemap-encode`, `sitemap-url`, `atom-encode`, `rss-encode`) into [`wensimehrp/exemel`](https://github.com/wensimehrp/exemel).
- [ ] Wait until `exemel:0.3.0` is merged into [`typst/packages`](https://github.com/typst/packages) and live at `https://typst.app/universe/package/exemel`.

### Step 2 — Publish `bfeitknecht/thyme` & submit `@preview/thyme:0.1.0`
- [ ] **Configure GitHub repo & Universe fork**
  - Create `bfeitknecht/thyme` on GitHub.
  - Fork `https://github.com/typst/packages` to `https://github.com/bfeitknecht/packages` (or set repo variable `UNIVERSE_FORK` if using another owner/fork).
  - Add repository secret `UNIVERSE_TOKEN` on `bfeitknecht/thyme` (fine-grained PAT with `Contents: Read and write` on `bfeitknecht/packages` and `Pull requests: Read and write` on `typst/packages`).
- [ ] **Remove temporary `exemel` vendoring once `exemel:0.3.0` is live**
  *(Note: `./scripts/stage-universe.sh` intentionally aborts while `vendor/exemel/` exists so an incomplete archive can never be submitted by accident.)*
  ```sh
  rm -rf vendor
  chmod +x scripts/*.sh
  ```
  - Remove the `// TODO` comment at the top of `src/seo.typ`.
  - Update the release date on `## [0.1.0] - YYYY-MM-DD` in `CHANGELOG.md` if needed.
- [ ] **Verify & stage locally against live Typst Universe**
  ```sh
  just docs && just check
  ./scripts/stage-universe.sh dist/universe
  ```
- [ ] **Cut `v0.1.0` & open the Universe PR**
  ```sh
  git init -b main
  git remote add origin git@github.com:bfeitknecht/thyme.git
  just release v0.1.0 "Initial release v0.1.0"
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
    chmod +x scripts/*.sh
    ```
- [ ] **Push & tag `bfeitknecht/glob` (once both `exemel:0.3.0` and `thyme:0.1.0` are live on Universe)**
  ```sh
  just compile
  git init -b main
  git remote add origin git@github.com:bfeitknecht/glob.git
  just release v0.1.0 "Initial release"
  ```
  *(Triggers `.github/workflows/publish-image.yaml` via `bfeitknecht/infra`, pushing `ghcr.io/bfeitknecht/glob:latest` for Flux/Keel to deploy.)*

### Step 4 — Update `bfeitknecht/apex` (`0xbf.ch`)
- [ ] Copy the files from `apex/` into your `bfeitknecht/apex` checkout (`cv.pdf`, `age.txt`, and `pgp.txt` already match upstream; replace `cv.pdf` if updated).
- [ ] **Choose deployment timing**
  - **Deploy immediately (before Universe PRs merge):** Keep `vendor/`; `justfile` and `Dockerfile` auto-detect `vendor/{exemel,thyme}` and compile offline.
  - **Switch to pure Typst Universe (after `exemel:0.3.0` & `thyme:0.1.0` merge):** Run `rm -rf vendor`; `justfile` and `Dockerfile` automatically pull `@preview/thyme:0.1.0` from Universe.
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
