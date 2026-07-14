# Compatibility matrix

This is the **canonical** compatibility reference for the tokopt ecosystem.
The sibling repositories link here rather than duplicating it, so there is a
single source of truth.

- CLI: [`shinyay/tokopt`](https://github.com/shinyay/tokopt) (this repo) —
  source at [`getting-started-with-token-optimization/tools/tokopt`](https://github.com/shinyay/getting-started-with-token-optimization/tree/main/tools/tokopt)
- VS Code extension: [`shinyay/tokopt-vscode`](https://github.com/shinyay/tokopt-vscode)
- Copilot skills: [`shinyay/tokopt-skills`](https://github.com/shinyay/tokopt-skills)

Each product follows its own [SemVer line](VERSIONING.md) — versions are **not**
kept numerically identical. Coordination is by this matrix plus periodic
**release trains**.

## Current releases

| Product | Current release |
|---|---|
| tokopt CLI / source | **0.18.0** |
| tokopt-vscode | **0.16.1** |
| tokopt-skills | **0.3.2** |

## Feature requirements (which CLI version a sibling feature needs)

| Consumer feature | Requires tokopt CLI | Below that |
|---|---|---|
| Extension: YAML/JSON slim preview | **≥ 0.15.0** (structured YAML/JSON → TOON support) | YAML/JSON preview is unavailable; Markdown slim remains available |
| Extension: machine-readable slim flag recommendations | **≥ 0.12.0** (`recommendations[]`) | Falls back to the extension's legacy Japanese-flag behavior |
| Extension: model cost comparison view (dashboard) | **≥ 0.10.0** (`tokopt report --by-model`) | Comparison section omitted; rest of dashboard unaffected |
| Extension: model picker auto-discovery (lists the binary's embedded models) | **≥ 0.9.0** (`tokopt models`) | Falls back to a built-in 4-model list |
| Extension: `--credit-rates` external rate card (`tokopt.creditRatesPath`) | **≥ 0.8.0** | Setting ignored |
| Extension / skills: AI Credit projection (`--credit-model`) | **≥ 0.8.0** | Tokens-only (no cost) |
| Skills: `slim --apply`, `rewind` | **≥ 0.7.0** | Command unavailable |

The extension and skills are written to **degrade gracefully** against an
older CLI rather than error — so a version mismatch loses a feature, never the
whole tool.

## Wire-format contracts

Independent of product versions (see [VERSIONING.md](VERSIONING.md#wire-contracts-format_version)):

| Contract | Field | Value (as of CLI 0.18.0) |
|---|---|---|
| Versioned CLI `--format=json` payloads | `format_version` | `"v1"`; command coverage and legacy exceptions are listed in the [canonical schema](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/tools/tokopt/docs/cli-json-schema.md) |
| Rate card (`rate-card.json`) | `format_version` | `1` |

## Release trains

A "wave" is a coordinated release where the products ship together, each with
its own appropriate bump. Versions differ on purpose.

| Wave | Theme | tokopt CLI | tokopt-vscode | tokopt-skills |
|---|---|---|---|---|
| (baseline) | Custom rate cards + 19-model card + picker discovery | 0.9.0 | 0.12.0 | 0.2.1 |
| Wave 1 | Model Cost Intelligence | 0.10.0 | 0.13.0 | 0.3.0 |
| **Current** | Trust Restoration: fidelity, Rewind safety, and machine contracts | **0.18.0** | **0.16.1** | **0.3.2** |

## How to update this file

- When a new sibling feature starts depending on a CLI capability, add a row to
  **Feature requirements**.
- When a JSON or rate-card schema changes incompatibly, bump the value in
  **Wire-format contracts** (and the schema's `format_version`).
- When a release wave is planned or shipped, add/annotate the row in
  **Release trains**.
