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

<!-- empty -->

## [0.5.1] — 2026-06-04

> **Solo binary distribution release.** Ships the `tokopt detect <FILE>`
> single-file scan mode + ENOTDIR fix that landed in source PR
> [shinyay/getting-started-with-token-optimization#106](https://github.com/shinyay/getting-started-with-token-optimization/pull/106).
> Sibling repos (`tokopt-skills`, `tokopt-vscode`) are unchanged in this
> round; their cleanup PRs will follow as separate small releases once
> consumers verify the new binary in the wild.

### Source release notes summary

The CLI binary in this release embeds the following source-level changes
since v0.4.0 (PR #106 — the **only** `tools/tokopt/` change in that
window; all other source commits were docs/site work shipped as
`getting-started v0.5.0`):

- **`tokopt detect <FILE>` — single-file scan mode**
  ([source #61](https://github.com/shinyay/getting-started-with-token-optimization/issues/61)) —
  `tokopt detect` now accepts a regular file as its positional
  argument. The repository root is inferred from the file's path
  via a 5-tier priority (well-known suffix patterns like
  `.github/copilot-instructions.md` / `.github/agents/*.agent.md` /
  `.github/skills/*/SKILL.md` first, then top-level customization
  filenames, then nearest `.git` marker — dir or file for
  worktree/submodule support — then nearest `.github/` ancestor,
  finally `filepath.Dir`). Findings are filtered to those mentioning
  the input file; for multi-file 'greppy' findings
  (`reasoning-leakage`, `polite-filler`, `format-inflation`) both
  `location` and `evidence` are narrowed to the input file's portion.
  The JSON envelope (`{format_version: "v1", findings: [...]}`) is
  **unchanged** → backward-compatible for `tokopt-vscode` v0.6.0 and
  `tokopt-skills` v0.2.0 consumers.

- **`tokopt detect`: ENOTDIR error class removed** (same issue) —
  passing a file path previously produced
  `"open <file>/.github/copilot-instructions.md: not a directory"`.
  Two layers of defense in depth (`antipatterns.Run` short-circuits
  on regular-file root; `readIfExists` treats `syscall.ENOTDIR` as
  `fs.ErrNotExist`) make this regression class unreachable.

Full source release notes:
<https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.5.1>

### Distribution surface (unchanged from v0.4.0)

- Platforms: `linux/amd64`, `linux/arm64`, `darwin/amd64`,
  `darwin/arm64`, `windows/amd64`
- Installer: `scripts/install.sh` (verifies `SHA256SUMS`, supports
  `--version`, `--prefix`, `--quiet`, `--dry-run` — no changes)
- Naming: `tokopt-v0.5.1-${OS}-${ARCH}.tar.gz` (Unix) +
  `tokopt-v0.5.1-windows-amd64.zip` (Windows manual download)
- macOS / Windows binaries remain **unsigned** (same Known issues as
  v0.4.0 apply)

### Build provenance

- Source: built from
  [`shinyay/getting-started-with-token-optimization`](https://github.com/shinyay/getting-started-with-token-optimization)
  tag [`v0.5.1`](https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.5.1)
  at commit `c20e173cb43fb297e5c661203b7f77e55b5d7977`.
- Toolchain: Go 1.26.2.
- Build flags: `CGO_ENABLED=0 -trimpath -ldflags "-s -w -X main.version=v0.5.1"`.
- **Default build** (NO `-tags nexusja`) — matches v0.4.0 baseline.
  Users who need the Kagome morphological JP Idiom stage
  (`JpIdiomKagome`, Order=38) should build from source with
  `-tags nexusja`. All other JP stages (`NexusJa`, `JpIdiom`
  heuristic, `JpIdiomCosmetic`, `JpFullwidthASCIINorm`) ship in
  these binaries.
- Cross-compiled from Linux/amd64; `CGO_ENABLED=0` ensures fully
  static binaries with no host C toolchain involvement.

### CLI delta vs v0.4.0

| Surface | v0.4.0 | v0.5.1 |
|---|---|---|
| `tokopt detect <DIR>` | scan directory tree, list findings | unchanged (byte-identical output) |
| `tokopt detect <FILE>` | error: `not a directory` | new single-file scan mode |
| JSON envelope | `{format_version: "v1", findings: [...]}` | unchanged |
| `Finding.location` field type | `string` | unchanged |
| `tokopt --help`, `--version`, all other subcommands | as v0.4.0 | unchanged |

### Companion plugins (unchanged versions)

The binaries pair with two open-standard plugin distributions, both
already compatible with v0.5.1 (no changes required to consume the
new file-mode detect):

- [`shinyay/tokopt-skills`](https://github.com/shinyay/tokopt-skills) v0.2.0 —
  Copilot CLI / Chat plugin (9 skills + 2 agents). Its
  `examples/batch/detect-all.sh` continues to use per-directory mode;
  a future patch may add an alternate per-file recipe demonstrating
  the new flow.
- [`shinyay/tokopt-vscode`](https://github.com/shinyay/tokopt-vscode) v0.6.0 —
  5-surface VS Code companion. Its `tokopt.tree.detectFile` workaround
  (scan whole workspace + filter findings client-side) is now
  redundant; a v0.6.1 patch will simplify the implementation to call
  `tokopt detect <file>` directly.

### Known issues (unchanged from v0.4.0)

- macOS binaries are unsigned (Gatekeeper workaround documented).
- Windows binaries are unsigned (SmartScreen warning).
- JSON schemas still carry `format_version: "v1"`; future `v2`
  would be a breaking schema change announced separately.
- The `tokopt version` **subcommand** form does NOT exist (use
  `tokopt --version` flag). Subcommand form tracked at
  [source #64](https://github.com/shinyay/getting-started-with-token-optimization/issues/64).

## [0.4.0] — 2026-05-30

> Part of a **coordinated 4-repo release** marking completion of the
> 3-repo specialization milestone. Sibling releases:
> [`getting-started-with-token-optimization` v0.4.0](https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.4.0) ·
> [`tokopt-skills` v0.2.0](https://github.com/shinyay/tokopt-skills/releases/tag/v0.2.0) ·
> [`tokopt-vscode` v0.6.0](https://github.com/shinyay/tokopt-vscode/releases/tag/v0.6.0).

### Changed

- Bumped pre-built binaries for all 5 platforms from v0.1.0 → v0.4.0.
  Same platforms, same naming convention, same installer flow — only
  the embedded CLI version (and the features it carries) change.

### Distribution surface (unchanged from v0.1.0)

- Platforms: `linux/amd64`, `linux/arm64`, `darwin/amd64`,
  `darwin/arm64`, `windows/amd64`
- Installer: `scripts/install.sh` (verifies `SHA256SUMS`, supports
  `--version`, `--prefix`, `--quiet`, `--dry-run` — no changes)
- Macros: macOS / Windows binaries remain unsigned (same Known
  issues as v0.1.0 apply)

### Build provenance

- Built from
  [`shinyay/getting-started-with-token-optimization`](https://github.com/shinyay/getting-started-with-token-optimization)
  source tag `v0.4.0`.
- Toolchain: Go 1.26.2.
- Build flags: `-trimpath -ldflags "-s -w -X main.version=v0.4.0"`.
- **Default build** (NO `-tags nexusja`) — matches v0.1.0 baseline.
  Users who need the Kagome morphological JP Idiom stage
  (`JpIdiomKagome`, Order=38) should build from source with
  `-tags nexusja`. All other JP stages (`NexusJa`, `JpIdiom`
  heuristic, `JpIdiomCosmetic`, `JpFullwidthASCIINorm`) ship in
  these binaries.

### What's new in the CLI (highlights since v0.1.0)

The binary distribution skipped v0.2.0 and v0.3.0; the v0.4.0 binaries
inherit everything shipped in the source repo across that window:

- **Profile bundles** (`--profile claude-md|agents-md|chat|api-json`)
  — one flag selects the right slim configuration per surface.
- **`chat-compact` command** — compresses Copilot Chat / API JSONL
  transcripts (tool-output truncation, tool-call truncation, tool
  include/exclude filters).
- **Japanese stages** — `NexusJa`, `JpIdiom`, `JpIdiomKagome`
  (kagome-only build), `JpIdiomCosmetic`, plus
  `JpFullwidthASCIINorm` (Phase R4.1, default OFF).
- **Rewind** — lossy stages persist input under SHA-256 for byte-
  exact recovery via `tokopt rewind get <hash>`. Retention / expiry
  / stats subcommands available.
- **`format_version: "v1"` envelope** — all JSON writers
  (`audit`, `detect`, `count`, `report`, errors) carry an explicit
  schema version so VS Code companions can degrade gracefully on
  future `v2` schemas.
- **`tokopt completion <bash|zsh|fish|powershell>`** — shell
  completion script generator.

Full source release notes:
<https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.4.0>

### Companion plugins

The binaries pair with two open-standard plugin distributions:

- [`shinyay/tokopt-skills`](https://github.com/shinyay/tokopt-skills) v0.2.0 —
  Copilot CLI / Chat plugin (9 skills + 2 agents) with shell-completion
  install instructions and a drop-in GitHub Actions CI recipe.
- [`shinyay/tokopt-vscode`](https://github.com/shinyay/tokopt-vscode) v0.6.0 —
  5-surface VS Code companion (CodeLens / Diagnostics / Quick Fix /
  Status bar / TreeView). CI does NOT need either plugin — the
  `tokopt` binary alone is sufficient.

### Known issues (unchanged from v0.1.0)

- macOS binaries are unsigned (Gatekeeper workaround documented).
- Windows binaries are unsigned (SmartScreen warning).
- JSON schemas now carry `format_version`; future `v2` will be a
  controlled break. Pinning `tokopt` to a specific version
  (`curl … | sh -s -- --version v0.4.0`) remains the recommended CI
  practice until v1.0.

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

[Unreleased]: https://github.com/shinyay/tokopt/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/shinyay/tokopt/releases/tag/v0.4.0
[0.1.0]: https://github.com/shinyay/tokopt/releases/tag/v0.1.0
