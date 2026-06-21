# Versioning policy

`tokopt` follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).
This document defines **what counts as the public API**, how version numbers
are chosen, and the criteria for the eventual `1.0.0` commitment. It is the
companion to the cross-product [COMPATIBILITY.md](COMPATIBILITY.md) matrix and
the maintainer [release runbook](docs/maintainer/release.md).

## What is the public API?

For SemVer purposes, a **breaking change** is any backward-incompatible change
to one of these surfaces:

- **Command names** (`audit`, `count`, `models`, …) and their **flags**
  (`--credit-model`, `--format`, …).
- **`--format json` output schemas** — keyed by the embedded
  `format_version` field (see [Wire contracts](#wire-contracts-format_version)).
- **Exit codes**: `0` ok, `1` runtime error, `2` budget exceeded
  (`report --threshold`).
- **The embedded rate-card schema** (`rate-card.json`, its own
  `format_version`).

Text/markdown human output is **not** part of the contract — it may be
reworded freely. Adding a new command, a new optional flag, or a new field to
a JSON object is **additive** (non-breaking).

## Choosing the version bump

### While in `0.x` (today)

Per SemVer §4, `0.y.z` means "initial development; anything MAY change." We
use the relaxed-but-disciplined convention:

| Change | Bump | Example |
|---|---|---|
| New feature, **additive** (new command/flag/field) | **MINOR** (`0.9 → 0.10`) | `tokopt models` |
| **Breaking** change to the public API | **MINOR** (`0.9 → 0.10`) | rename a flag |
| Bug fix, docs, internal refactor (no API change) | **PATCH** (`0.9.0 → 0.9.1`) | fix slim idempotency |

So in `0.x`, both features **and** breaking changes ride a MINOR bump — the
`0.` prefix is itself the "unstable" signal. Breaking changes should still be
called out under a `### Changed` / `### Removed` heading in `CHANGELOG.md`.

### After `1.0.0`

Standard SemVer: **MAJOR** = breaking, **MINOR** = additive, **PATCH** = fixes.

## Wire contracts (`format_version`)

The CLI's machine-readable outputs carry their **own** version, independent of
the product version, so consumers (e.g. the VS Code extension) can rely on the
wire format across many product releases:

| Contract | Field | Current |
|---|---|---|
| `count` / `audit` / `anatomy` / `models` JSON | `format_version` | `"v1"` |
| Embedded & external rate card | `format_version` | `1` |

Rules:

- **Adding** a field to a JSON object is non-breaking → do **not** bump
  `format_version` (e.g. `rate_basis` and the per-model `basis` were additive).
- **Renaming/removing** a field or changing its meaning **is** breaking → bump
  `format_version` and keep readers tolerant (unknown → graceful fallback).

This decoupling lets the product SemVer track release cadence while
`format_version` tracks schema stability.

## Road to `1.0.0`

`1.0.0` is a **commitment to stability**, not a "we have enough features"
milestone. We cut `1.0.0` when we are ready to promise we will not break the
public API without a MAJOR bump. Checklist:

- [ ] A second real user / team depends on it, **or** we publish broadly
      (e.g. VS Code Marketplace listing, public announcement).
- [ ] The command/flag set and JSON `format_version=v1` schemas are ones we
      are willing to freeze.
- [ ] The rate-card schema is frozen.
- [ ] Docs and verification are complete.

Until then we stay in `0.x` and keep breaking changes cheap.

## Coordination with sibling products

`tokopt` is the dependency root for the
[VS Code extension](https://github.com/shinyay/tokopt-vscode) and the
[Copilot skills](https://github.com/shinyay/tokopt-skills). Those products
version **independently** — we deliberately do **not** force a shared number.
Coordination happens through:

- [COMPATIBILITY.md](COMPATIBILITY.md) — the canonical matrix of which CLI
  version each sibling feature requires.
- **Release trains** — periodic coordinated "waves" where all three ship
  together, each with its own appropriate bump.

## Source-of-truth note

The CLI **source** lives in
[shinyay/getting-started-with-token-optimization](https://github.com/shinyay/getting-started-with-token-optimization)
under `tools/tokopt/`; its `vX.Y.Z` git tags **are** the tokopt CLI versions.
This repository (`shinyay/tokopt`) is the **binary distribution** and is tagged
to match. See [docs/maintainer/release.md](docs/maintainer/release.md).
