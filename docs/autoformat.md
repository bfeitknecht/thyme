# Autoformat, lint, and cleanup configuration for `thyme`

## Typst Codebase
- **Typst CLI**: `typst fmt` (available in Typst >= 0.15.1) formats `.typ` files automatically.
- **Formatting**: `just fmt` runs `typst fmt` across the entire codebase.
- **Linting**: `just lint` checks for common Typst syntax issues and unused imports.

## Python Scripts
- **Autoformat**: `ruff format` formats `.py` files.
- **Linting**: `ruff check` checks for style and logic issues.

## Justfile
- **Formatting**: `justfmt` formats the `justfile` (if installed).
- **Linting**: `just lint` checks `justfile` syntax.

## CI Integration
- **GitHub Actions**: Added `format` and `lint` jobs to `ci.yaml`.
- **Release**: `release.yaml` now includes formatting checks before staging.

## Usage
- Run `just fmt` to autoformat all files.
- Run `just lint` to check for issues.
- Run `just check` (existing) to run full compilation and verification.

## Cleanup
- Removed stale imports and temporary files.
- Added `.pre-commit-config.yaml` for local development.
- Added `pyproject.toml` for Python dependencies.

## Pre-commit Hooks
- Install hooks: `pre-commit install`
- Run hooks: `pre-commit run --all-files`
