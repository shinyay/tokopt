# Changelog

All notable changes to the **tokopt binary distribution** are documented in
this file. For the underlying CLI source-code changes, see the
[source repo CHANGELOG](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/CHANGELOG.md).

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

The scope of this changelog is the **distribution**: pre-built binaries,
the `scripts/install.sh` installer, issue templates, and end-user docs.
Changes to the `tokopt` CLI itself (commands, flags, output schemas,
detectors) live in the source repo's CHANGELOG and are summarised here
under each release's _Source release notes_ section.

## [Unreleased]

_(empty)_

## [0.1.0] — 2026-04-XX

### Added

- Initial public release of the tokopt binary distribution.
- Pre-built binaries for 5 platforms:
  - `linux/amd64`, `linux/arm64`
  - `darwin/amd64`, `darwin/arm64`
  - `windows/amd64`
- Comprehensive end-user documentation following the
  [Diátaxis](https://diataxis.fr/) framework:
  - **Getting started**: `installation.md`, `quickstart.md`
  - **Concepts**: `three-layer-model`, `always-on-tax`, `token-vocabulary`
  - **Commands**: per-command reference for `audit`, `anatomy`, `count`,
    `detect`, `report`, `tail`
  - **Reference**: `cli-reference`, `exit-codes`, `encodings`,
    `output-formats`
  - **Use cases**: 5 how-to guides
  - **Integrations**: VS Code Tasks, Copilot Chat skills + agent,
    GitHub Actions
- POSIX install script (`scripts/install.sh`) with:
  - SHA256 verification against `SHA256SUMS` published with each release
  - Idempotency check (skip if the requested version is already installed)
  - Version pinning via `--version` flag or `TOKOPT_VERSION` env var
  - `--prefix` for user-local installs (defaults to `/usr/local/bin` with
    sudo fallback, then `~/.local/bin`)
  - `--dry-run` and `--quiet` modes
  - Honest, machine-actionable error messages with a fallback link to the
    releases page
- 5 issue templates in `.github/ISSUE_TEMPLATE/` plus `config.yml`:
  `bug_report`, `feature_request`, `use_case`, `question`.
- Docs lint CI (markdownlint + `lychee` link checker).

### Source release notes

This binary release packages **tokopt v0.1.0** from the source repo.
Highlights from the source-side changelog:

- 6 commands: `audit`, `anatomy`, `detect`, `tail`, `report`, `count`.
- 10 anti-pattern detectors with severities `info` / `warn` / `high` /
  `critical`.
- Two tokenizer encodings: `o200k_base` (default) and `cl100k_base`.
- Persistent `--version` flag (source-repo commit
  [`9965f0e`](https://github.com/shinyay/getting-started-with-token-optimization/commit/9965f0e)).
- Bug-fix: `audit` now scans `.github/agents/` in addition to root-level
  `agents/` (source-repo commit
  [`5ba4b9e`](https://github.com/shinyay/getting-started-with-token-optimization/commit/5ba4b9e)).
  On a real target repo this had been under-reporting `conditional` tokens
  by 8,114 tokens (9 agent files, all counted as zero). The bug was
  surfaced by an LLM agent (`token-doctor`) cross-checking `tokopt audit`
  output against an independent shell-glob ground truth — a documented
  pattern under [docs/use-cases/auditing-a-template-repo.md](docs/use-cases/auditing-a-template-repo.md).

Full source-repo release notes:
<https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.1.0>

### Known issues

- **macOS binaries are unsigned** — Gatekeeper will block first launch.
  Workaround: remove the quarantine attribute with
  `xattr -d com.apple.quarantine "$(which tokopt)"`. See
  [docs/troubleshooting.md](docs/troubleshooting.md).
- **Windows binaries are unsigned** — SmartScreen may show a warning;
  click "More info" → "Run anyway". Code signing is on the roadmap for
  v1.0.
- **Output JSON schemas may evolve until v1.0** — pin `tokopt` to a
  specific version in CI scripts (e.g.
  `curl … | sh -s -- --version v0.1.0`) until v1.0 stabilises the
  schemas. See [docs/maintainer/release.md](docs/maintainer/release.md#versioning-policy-semver)
  for the full policy.

[Unreleased]: https://github.com/shinyay/tokopt/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/shinyay/tokopt/releases/tag/v0.1.0
