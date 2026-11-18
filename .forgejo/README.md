# `.forgejo/workflows`

- `ci.yaml` mirrors `.github/workflows/ci.yaml` for a Forgejo runner:
  `runs-on: ubuntu-latest` (the cluster forgejo-runner label) and
  fully-qualified action URLs.
- `release.yaml` has no mirror. It publishes the GitHub Release and opens the
  Typst Universe submission PR; both are GitHub-side. Releases stay on
  GitHub, the mirror carries the code.
