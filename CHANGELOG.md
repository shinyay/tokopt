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

## [0.8.0] — 2026-06-06

> **Credit projection release.** Ships the `tokopt audit / count / anatomy --credit-model=<X>` flag that projects token counts into Copilot AI Credit (**nano-AIU**) using empirical rates measured from real Copilot CLI ephemeral sessions. Four model families calibrated, **8.3× rate spread** between cheapest and most expensive. Source release [v0.8.0](https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.8.0) (source PRs [#120](https://github.com/shinyay/getting-started-with-token-optimization/pull/120) and [#122](https://github.com/shinyay/getting-started-with-token-optimization/pull/122), closing [source #119](https://github.com/shinyay/getting-started-with-token-optimization/issues/119) and [source #121](https://github.com/shinyay/getting-started-with-token-optimization/issues/121)). No distribution-surface changes — same 5-platform matrix, same installer, same SHA256SUMS format.

### Source release notes summary

The CLI binary in this release embeds the following source-level changes since v0.7.0 — unified by one coherent capability: **turning the existing measurement commands (`audit`, `count`, `anatomy`) from pure token reporters into Copilot AI Credit (AIU) projectors**.

- **`tokopt audit --credit-model=<X>`**
  ([source #121](https://github.com/shinyay/getting-started-with-token-optimization/issues/121),
  [source PR #122](https://github.com/shinyay/getting-started-with-token-optimization/pull/122))
  — projects per-file and per-bucket token counts into nano-AIU for a specific Copilot CLI model. Adds a `NANO-AIU` column to the per-file table and prints a `Credit projection` footer with per-bucket AIU totals plus the worst-case total per turn. Embedded rate card covers the 4 model families benchmarked in source Phase 12.A: `gpt-5.5`, `claude-opus-4.7-1m-internal`, `gemini-3.1-pro-preview`, `mai-code-1-flash-internal`. Unknown model names fail fast with a list of known models. JSON output gains a `credit` block (omitempty) with `model`, `rate_source`, `rate_measured_at`, `nano_aiu_per_input_token`, plus per-bucket and total nano-AIU. Without the flag, audit output is byte-equal to v0.7.0.

- **`tokopt count --credit-model=<X>`** — adds `≈N nano-AIU` to text output and `nano_aiu` field to JSON output (per-file in multi-file mode, plus a `credit_model` envelope key). Single-argument JSON shape preserved when flag absent (byte-equal to v0.7.0).

- **`tokopt anatomy --credit-model=<X>`** — adds a `NANO-AIU` column to the per-segment table and prints a per-turn AIU total in the footer.

- **`tokopt --credit-rates=<path>`** — global override flag for the embedded rate card. Loads an external `bench/rate-card.json` (same schema as the embedded default). Useful when re-calibrating for newer Copilot CLI versions or when measuring with non-shipped models.

The rate card itself is produced by the new `bench/` standalone Python runner that also lands in source v0.8.0 ([source PR #120](https://github.com/shinyay/getting-started-with-token-optimization/pull/120)). The runner is NOT part of the binary distribution — it stays in the source repo and is run on a per-need basis when new models ship or rates need refreshing. The procedure is documented at [foundations/aiu-and-rate-cards](https://shinyay.github.io/getting-started-with-token-optimization/foundations/aiu-and-rate-cards/).

### CLI delta vs v0.7.0

| Command | Status in v0.8.0 |
|---|---|
| `tokopt audit --credit-model=<X>` | **NEW flag** — per-bucket AIU projection |
| `tokopt count --credit-model=<X>` | **NEW flag** — per-file AIU projection (single + multi-file) |
| `tokopt anatomy --credit-model=<X>` | **NEW flag** — per-segment AIU projection |
| `--credit-rates=<path>` (global) | **NEW flag** — external rate card override |
| `tokopt audit` (no flag) | unchanged (byte-identical text/JSON to v0.7.0) |
| `tokopt count <file...>` (no flag) | unchanged (byte-identical to v0.7.0 for both single- and multi-file shapes) |
| `tokopt anatomy <file>` (no flag) | unchanged (byte-identical to v0.7.0) |
| `tokopt audit --follow-references` | unchanged from v0.7.0 |
| All other commands (`slim`, `detect`, `chat-compact`, `tail`, `rewind`, `version`, `report`, `help`) | unchanged |

### Empirical findings shipped in the embedded rate card

The 4 model families calibrated reveal an 8.3× rate spread (nano-AIU per input token, Copilot-CLI-turn-normalized):

| Model | nano-AIU / input token | Relative |
|---|---:|---:|
| `mai-code-1-flash-internal` | 75,000 | **1.0×** (cheapest) |
| `gemini-3.1-pro-preview` | 190,849 | 2.5× |
| `gpt-5.5` | 312,500 | 4.2× |
| `claude-opus-4.7-1m-internal` | 621,782 | **8.3×** (most expensive) |

The rate card is an **input-dominant empirical approximation** — it includes the fixed ~24k system+tools context overhead amortized into per-input-token cost, does NOT separately model output / cache_read / cache_write / reasoning rates, and is intended for **comparative model-selection analysis**, not as a substitute for the GitHub Copilot billing dashboard. Limitations documented at [foundations/aiu-and-rate-cards](https://shinyay.github.io/getting-started-with-token-optimization/foundations/aiu-and-rate-cards/).

### Back-compat

Without `--credit-model`, all three measurement commands produce output that is **byte-identical** to v0.7.0. Enforced by:

- `omitempty` JSON tags on every new struct field (`credit`, `nano_aiu`, etc.)
- 10 integration tests in source `tools/tokopt/cmd/tokopt/credit_test.go` assert ABSENCE of credit keys when the flag is absent across text + JSON + md formats
- Full `go test -race ./...` green for all 14 source packages

Existing users see **zero change** until they opt in. Existing `jq` pipelines, CI gates, and downstream tooling are unaffected.

### Distribution surface (unchanged from v0.7.0)

Same 5-platform matrix, same installer behaviour, same asset naming contract, same SHA256SUMS format. Re-running the v0.7.0 installer with `--version v0.8.0` (or with no version flag once the release is live) upgrades cleanly.

- `tokopt-v0.8.0-linux-amd64.tar.gz`
- `tokopt-v0.8.0-linux-arm64.tar.gz`
- `tokopt-v0.8.0-darwin-amd64.tar.gz`
- `tokopt-v0.8.0-darwin-arm64.tar.gz`
- `tokopt-v0.8.0-windows-amd64.zip`
- `SHA256SUMS` (covers all 5)

### Refresh procedure (for re-calibration)

When new Copilot CLI versions ship or you want to re-measure:

```bash
# Source repo
python3 bench/run.py update-rate-card --models=<list> --yes
cp bench/rate-card.json tools/tokopt/internal/credit/rates_embedded.json
cd tools/tokopt && go build -o ~/bin/tokopt ./cmd/tokopt
```

Or supply your own rate card at runtime without rebuilding:

```bash
tokopt audit . --credit-model=gpt-5.5 --credit-rates=/path/to/my-rate-card.json
```

## [0.7.0] — 2026-06-05

> **Two-feature bundle release.** Ships the `tokopt count <files...>`
> multi-file mode and the `tokopt audit --follow-references` dynamic
> Markdown reference resolver — both landed in source release
> [v0.7.0](https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.7.0)
> (source PRs [#110](https://github.com/shinyay/getting-started-with-token-optimization/pull/110)
> and [#111](https://github.com/shinyay/getting-started-with-token-optimization/pull/111),
> closing [source #62](https://github.com/shinyay/getting-started-with-token-optimization/issues/62)
> and [source #63](https://github.com/shinyay/getting-started-with-token-optimization/issues/63)).
> Sibling repos (`tokopt-skills`, `tokopt-vscode`) get one-line update
> for `--follow-references` discoverability and a no-change verification
> respectively.

### Source release notes summary

The CLI binary in this release embeds the following source-level
changes since v0.6.1 — unified by a coherent "complete the scan
surface" narrative (together they answer "what does my repo cost?"
for both arbitrary file lists and dynamically referenced agent
dependencies):

- **`tokopt count <files...>` — multi-file mode**
  ([source #62](https://github.com/shinyay/getting-started-with-token-optimization/issues/62),
  [source PR #110](https://github.com/shinyay/getting-started-with-token-optimization/pull/110)) —
  `count` now accepts any number of file paths and scans them in a
  single subprocess instead of N. Matches the conventions of `wc`,
  `du`, and `cloc`. In text mode, each file gets its own per-line
  entry and a `total` line is appended when more than one path is
  supplied. In JSON mode, a single-argument invocation keeps the exact
  pre-v0.7.0 flat envelope shape (byte-equal back-compat), while a
  multi-argument invocation emits a single envelope
  `{format_version, encoding, files: [{path, tokens, bytes}, …],
  total: {tokens, bytes}}` so downstream `jq` pipelines work with one
  subprocess instead of N. All-or-nothing semantics: if any file
  fails to read, no per-file output is emitted (error is returned,
  exit code is non-zero). Stdin (`-`) remains supported but must be
  the sole argument — `tokopt count file.md -` and `tokopt count - -`
  are rejected with a clear error message. Performance: scanning a
  20-file subset becomes 1 subprocess instead of 20.

- **`tokopt audit --follow-references` — dynamic Markdown ref resolver**
  ([source #63](https://github.com/shinyay/getting-started-with-token-optimization/issues/63),
  [source PR #111](https://github.com/shinyay/getting-started-with-token-optimization/pull/111)) —
  opt-in (default OFF), best-effort path resolver that scans
  agent/chatmode/copilot-instructions bodies for free-text references
  to other `.md` files and surfaces resolved files that are NOT
  already classified by static rules. **Surfaces the ~60% under-count
  gap measured on real coordinator-style configs**
  (`plan-agent-for-vscode`: 11,760 tokens classified statically vs
  18,765 worst-case runtime cost; 7,005-token delta from
  `.github/instructions/*.md` files referenced by name from the
  coordinator agent body but lacking `applyTo:` frontmatter). Three
  regex patterns are matched (markdown link, bare path, backtick-
  wrapped); two-strategy resolve (source dir → root-anchored fallback)
  with a 9-step safety pipeline (URL/abs/escape/symlink/exists/dedup).
  JSON output adds `dynamic_references[]` array +
  `dynamic_references_total` field (both `omitempty` when flag is
  off). A discoverability tip (text mode only) suggests the flag when
  the flag is OFF and the repo has at least one agent-shaped source.
  Findings are explicitly labelled "best-effort, may not load" to
  manage false-positive expectations — the tool does NOT model agent
  dispatch logic, only path references. `tokopt report
  --follow-references` mirrors `audit`.

### CLI delta vs v0.6.1

| Command | Status in v0.7.0 |
|---|---|
| `tokopt count <files...>` | **CHANGED** — accepts N files, text/JSON envelope shape per arg-count |
| `tokopt audit --follow-references` | **NEW flag** — opt-in dynamic ref resolver |
| `tokopt report --follow-references` | **NEW flag** — mirrors audit |
| `tokopt count <file>` (single arg) | unchanged (byte-identical JSON to v0.6.1) |
| `tokopt audit` (no flag) | unchanged (byte-identical text/JSON to v0.6.1) |
| All other commands (`anatomy`, `slim`, `detect`, `chat-compact`, `tail`, `rewind`, `version`) | unchanged |

### Distribution surface (unchanged from v0.6.1)

Same 5-platform matrix, same installer behaviour, same asset naming
contract, same SHA256SUMS format. Re-running the v0.6.1 installer
invocation with the version bumped works without any additional
flags:

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \
  | sh -s -- --version v0.7.0
```

| Asset | OS | ARCH | Format |
|---|---|---|---|
| `tokopt-v0.7.0-linux-amd64.tar.gz` | linux | amd64 | tar.gz |
| `tokopt-v0.7.0-linux-arm64.tar.gz` | linux | arm64 | tar.gz |
| `tokopt-v0.7.0-darwin-amd64.tar.gz` | darwin | amd64 | tar.gz |
| `tokopt-v0.7.0-darwin-arm64.tar.gz` | darwin | arm64 | tar.gz |
| `tokopt-v0.7.0-windows-amd64.zip` | windows | amd64 | zip |
| `SHA256SUMS` | — | — | text |

### Build provenance

| Field | Value |
|---|---|
| Source repo | [`shinyay/getting-started-with-token-optimization`](https://github.com/shinyay/getting-started-with-token-optimization) |
| Source tag | [`v0.7.0`](https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.7.0) |
| Source commit | [`fa7455c`](https://github.com/shinyay/getting-started-with-token-optimization/commit/fa7455c) |
| Toolchain | Go 1.26.2 |
| Build flags | `-trimpath -ldflags "-s -w -X main.version=v0.7.0"` |
| `CGO_ENABLED` | `0` (all 5 platforms) |
| Build tags | none (no `-tags nexusja` — kagome ships only via source build) |

### Companion plugins (this round)

| Plugin | Latest release | Compatibility |
|---|---|---|
| [`shinyay/tokopt-skills`](https://github.com/shinyay/tokopt-skills) | v0.2.1 | ✅ Compatible — one-line `--follow-references` mention pending in `token-audit` SKILL.md |
| [`shinyay/tokopt-vscode`](https://github.com/shinyay/tokopt-vscode) | v0.6.3 | ✅ Compatible — no-change (flag is opt-in; static classification unaffected) |

### Known issues

- _(none carried over)_

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
```

Or pin to this exact version:

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh -s -- --version v0.7.0
```

### Refs

- Source PRs: [#110 (count)](https://github.com/shinyay/getting-started-with-token-optimization/pull/110) + [#111 (audit-refs)](https://github.com/shinyay/getting-started-with-token-optimization/pull/111)
- Source release: [v0.7.0](https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.7.0)
- Source issues: [#62 (count multi-file)](https://github.com/shinyay/getting-started-with-token-optimization/issues/62) + [#63 (audit follow-references)](https://github.com/shinyay/getting-started-with-token-optimization/issues/63)

## [0.6.1] — 2026-06-05

> **Solo binary distribution release.** Ships the `tokopt version`
> subcommand from source PR
> [shinyay/getting-started-with-token-optimization#109](https://github.com/shinyay/getting-started-with-token-optimization/pull/109)
> (closes [source #64](https://github.com/shinyay/getting-started-with-token-optimization/issues/64)).
> Sibling repos (`tokopt-skills`, `tokopt-vscode`) are unchanged in this
> round.

### Source release notes summary

The CLI binary in this release embeds the following source-level
changes since v0.6.0 (PR #109 — the **only** `tools/tokopt/` change
in that window):

- **`tokopt version` subcommand**
  ([source #64](https://github.com/shinyay/getting-started-with-token-optimization/issues/64)) —
  adds the long-requested `tokopt version` subcommand as a peer of the
  existing `tokopt --version` flag. Both forms now emit byte-identical
  output (`tokopt version v0.6.1\n`), following the prevailing CLI
  convention (`git version`, `docker version`, `kubectl version`,
  `gh version`, `go version`). The subcommand routes through a
  `PersistentPreRunE` bypass so it remains usable even when `--format`
  is invalid — i.e. `tokopt --format=bad version` succeeds and matches
  `tokopt --format=bad --version`, preserving the "interchangeable"
  contract.

### CLI delta vs v0.6.0

| Command | Status in v0.6.1 |
|---|---|
| `tokopt version` | **NEW** subcommand |
| `tokopt --version` | unchanged |
| All other commands (`audit`, `anatomy`, `slim`, `detect`, `count`, `chat-compact`, `tail`, `rewind`, `report`) | unchanged |

### Distribution surface (unchanged from v0.6.0)

Same 5-platform matrix, same installer behaviour, same asset naming
contract, same SHA256SUMS format. Re-running the v0.6.0 installer
invocation with the version bumped works without any additional
flags:

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \
  | sh -s -- --version v0.6.1
```

| Asset | OS | ARCH | Format |
|---|---|---|---|
| `tokopt-v0.6.1-linux-amd64.tar.gz` | linux | amd64 | tar.gz |
| `tokopt-v0.6.1-linux-arm64.tar.gz` | linux | arm64 | tar.gz |
| `tokopt-v0.6.1-darwin-amd64.tar.gz` | darwin | amd64 | tar.gz |
| `tokopt-v0.6.1-darwin-arm64.tar.gz` | darwin | arm64 | tar.gz |
| `tokopt-v0.6.1-windows-amd64.zip` | windows | amd64 | zip |
| `SHA256SUMS` | — | — | text |

### Build provenance

| Field | Value |
|---|---|
| Source repo | [`shinyay/getting-started-with-token-optimization`](https://github.com/shinyay/getting-started-with-token-optimization) |
| Source tag | [`v0.6.1`](https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.6.1) |
| Source commit | [`f3f1c8d`](https://github.com/shinyay/getting-started-with-token-optimization/commit/f3f1c8d) |
| Toolchain | Go 1.26.2 |
| Build flags | `-trimpath -ldflags "-s -w -X main.version=v0.6.1"` |
| `CGO_ENABLED` | `0` (all 5 platforms) |
| Build tags | none (no `-tags nexusja` — kagome ships only via source build) |

### Companion plugins (unchanged versions in this round)

| Plugin | Latest release | Compatibility |
|---|---|---|
| [`shinyay/tokopt-skills`](https://github.com/shinyay/tokopt-skills) | v0.2.1 | ✅ Compatible (no anatomy positional touch in v0.2.1 release; recipes update tracked) |
| [`shinyay/tokopt-vscode`](https://github.com/shinyay/tokopt-vscode) | v0.6.3 | ✅ Compatible (CodeLens detail string update tracked separately) |

### Known issues

- _(no carried-over issues — `tokopt version` subcommand from v0.6.0 known-issues list is now resolved)_

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
```

Or pin to this exact version:

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh -s -- --version v0.6.1
```

### Refs

- Source PR: [shinyay/getting-started-with-token-optimization#109](https://github.com/shinyay/getting-started-with-token-optimization/pull/109)
- Source release: [v0.6.1](https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.6.1)
- Source issue: [#64](https://github.com/shinyay/getting-started-with-token-optimization/issues/64)
- Distribution PR: tokopt#6 (this release)

## [0.6.0] — 2026-06-05

> **Solo binary distribution release.** Ships the `tokopt anatomy <file>`
> positional auto-classification feature that landed in source PR
> [shinyay/getting-started-with-token-optimization#108](https://github.com/shinyay/getting-started-with-token-optimization/pull/108)
> (closes [source #60](https://github.com/shinyay/getting-started-with-token-optimization/issues/60)).
> Sibling repos (`tokopt-skills`, `tokopt-vscode`) are unchanged in this
> round; their integration PRs that consume the new positional
> `anatomy` surface will follow as separate small releases once
> consumers verify the new binary in the wild.

### Source release notes summary

The CLI binary in this release embeds the following source-level
changes since v0.5.1 (PR #108 — the **only** `tools/tokopt/` change
in that window):

- **`tokopt anatomy <file>` — positional auto-classification**
  ([source #60](https://github.com/shinyay/getting-started-with-token-optimization/issues/60)) —
  `tokopt anatomy` now accepts a single positional file argument.
  When the file matches a recognised Copilot/agent customization
  shape, the canonical 7-segment slot is inferred from the file's
  name and path, the rule is rendered in the report header (text
  mode), italicized in markdown mode, or surfaced as two new
  optional JSON fields (`inferred_segment` + `inference_rule`,
  both `omitempty`). Nine shapes are recognised:
  `copilot-instructions.md` / `AGENTS.md` / `instructions.md`
  (always-on; path-anchored to repo root or `.github/`),
  `*.agent.md` / `*.chatmode.md` / `*.instructions.md`
  (conditional), `*.prompt.md` / `SKILL.md` (on-demand), and MCP
  configs (`mcp(-config)?.json` under `.copilot/`, `.vscode/`,
  `.cursor/`). Unrecognised shapes exit with a structured
  `UNRECOGNIZED_SHAPE` error envelope and a hint suggesting an
  explicit `--<segment>` flag. The positional form is mutually
  exclusive with `--json` and the per-segment flags.

- **JSON error envelope: new optional `hint` field** — when an error
  message carries an embedded `\nhint: ...` suffix (e.g., the new
  `UNRECOGNIZED_SHAPE` error), the hint body is also surfaced as a
  structured `hint` field on the error envelope (`omitempty`), so
  JSON consumers don't need to parse the human-readable message.
  The `message` field retains the original full text, so text-mode
  stderr is unchanged.

- **Path-anchoring + denylist for root sentinels** — bare basename,
  `./AGENTS.md`, `.github/AGENTS.md`, and absolute paths to root
  sentinels all classify correctly; nested relative
  `docs/.github/AGENTS.md` is rejected, and absolute paths whose
  immediate parent directory is in a small false-positive denylist
  (`docs`, `documentation`, `examples`, `node_modules`, `vendor`,
  `test`, `tests`, `__tests__`, `third_party`, `target`, `build`,
  `dist`, `out`) are also rejected. So doc-mirrored copies of agent
  files do not trigger spurious matches.

- **New `internal/classify` package** — zero-dependency,
  path-based classifier extracted to its own package so future
  audit work (e.g., [source #63](https://github.com/shinyay/getting-started-with-token-optimization/issues/63)
  `audit --follow-references`) can reuse it without import cycles.

Full source release notes:
<https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.6.0>

### Distribution surface (unchanged from v0.5.1)

- Platforms: `linux/amd64`, `linux/arm64`, `darwin/amd64`,
  `darwin/arm64`, `windows/amd64`
- Installer: `scripts/install.sh` (verifies `SHA256SUMS`, supports
  `--version`, `--prefix`, `--quiet`, `--dry-run` — no changes)
- Naming: `tokopt-v0.6.0-${OS}-${ARCH}.tar.gz` (Unix) +
  `tokopt-v0.6.0-windows-amd64.zip` (Windows manual download)
- macOS / Windows binaries remain **unsigned** (same Known issues as
  v0.5.1 apply)

### Build provenance

- Source: built from
  [`shinyay/getting-started-with-token-optimization`](https://github.com/shinyay/getting-started-with-token-optimization)
  tag [`v0.6.0`](https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v0.6.0)
  at commit `2fecf084d10dfad562ed72e14cf2b30e109492fe`.
- Toolchain: Go 1.26.2.
- Build flags: `CGO_ENABLED=0 -trimpath -ldflags "-s -w -X main.version=v0.6.0"`.
- **Default build** (NO `-tags nexusja`) — matches v0.4.0/v0.5.1
  baseline. Users who need the Kagome morphological JP Idiom stage
  (`JpIdiomKagome`, Order=38) should build from source with
  `-tags nexusja`. All other JP stages (`NexusJa`, `JpIdiom`
  heuristic, `JpIdiomCosmetic`, `JpFullwidthASCIINorm`) ship in
  these binaries.
- Cross-compiled from Linux/amd64; `CGO_ENABLED=0` ensures fully
  static binaries with no host C toolchain involvement.

### CLI delta vs v0.5.1

| Surface | v0.5.1 | v0.6.0 |
|---|---|---|
| `tokopt anatomy --<seg> <file>` flag-driven | report 7-segment breakdown | unchanged (byte-identical JSON envelope) |
| `tokopt anatomy <file>` positional | error: `accepts 0 args` | new auto-classification mode |
| Anatomy text-mode header | `tokopt anatomy  encoding=… total=…` | adds `↑ inferred segment: <seg> (rule: <r>)` line when positional |
| Anatomy md-mode rendering | numeric table only | adds italic inference line with backtick-wrapped rule when positional |
| Anatomy JSON envelope (flag-driven) | `{format_version, encoding, segments, total_input_tokens, warnings}` | unchanged (additive fields use `omitempty`) |
| Anatomy JSON envelope (positional) | n/a | adds `inferred_segment`, `inference_rule` |
| JSON error envelope | `{code, kind, message, exit_code, subcommand}` | adds `hint?` (omitempty, populated when message has `\nhint:` suffix) |
| `tokopt anatomy <file> <file2>` (≥2 positional) | silently ignored | rejected via `cobra.MaximumNArgs(1)` |
| All other subcommands (`count`, `detect`, `audit`, `slim`, `tail`, `chat-compact`, `antipatterns`) | as v0.5.1 | unchanged |

### Companion plugins (unchanged versions)

The binaries pair with two open-standard plugin distributions, both
already compatible with v0.6.0 (no changes required for existing
flag-driven usage; positional-form integration is opt-in):

- [`shinyay/tokopt-skills`](https://github.com/shinyay/tokopt-skills) v0.2.x —
  Copilot CLI / Chat plugin (9 skills + 2 agents). Existing flag-driven
  `tokopt anatomy` usage in recipes continues to work; a future patch
  may add an alternate `examples/anatomy/auto-classify-*.sh` recipe
  showcasing the new positional form.
- [`shinyay/tokopt-vscode`](https://github.com/shinyay/tokopt-vscode) v0.6.3 —
  5-surface VS Code companion. CodeLens / TreeView surfaces may
  evolve to call `tokopt anatomy <file>` directly (replacing the
  current per-segment flag plumbing) in a future patch release.

### Known issues (unchanged from v0.5.1)

- macOS binaries are unsigned (Gatekeeper workaround documented).
- Windows binaries are unsigned (SmartScreen warning).
- JSON schemas still carry `format_version: "v1"`; future `v2`
  would be a breaking schema change announced separately.
- The `tokopt version` **subcommand** form does NOT exist (use
  `tokopt --version` flag). Subcommand form tracked at
  [source #64](https://github.com/shinyay/getting-started-with-token-optimization/issues/64).

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
