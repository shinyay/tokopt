# `tokopt detect`

Run static-config anti-pattern detectors against a repository and surface
each finding with a severity, evidence, fix, and (when measurable)
estimated tokens saved.

## Synopsis

```bash
tokopt detect [path] [--format text|json|md] [--encoding o200k_base|cl100k_base]
```

## Description

Walks `path` (default `.`) and runs every detector defined in
`internal/antipatterns`. Findings are sorted by `est_tokens_saved`
descending, then by id. Exit code is **0 even when findings exist** —
`detect` is informational. Use [`report --threshold`](report.md) for CI
gating.

## Arguments

| Name   | Required | Default | Description                            |
|--------|----------|---------|----------------------------------------|
| `path` | no       | `.`     | Directory to scan. Must be a directory. |

## Flags

`detect` has no flags of its own. It honours the persistent flags:

| Flag         | Type   | Default      | Description                                |
|--------------|--------|--------------|--------------------------------------------|
| `--encoding` | string | `o200k_base` | Tokenizer encoding.                        |
| `--format`   | string | `text`       | Output format: `text`, `json`, or `md`.    |

`--reference-window` has no effect on `detect`.

## Detectors

All severities are one of `info`, `warn`, `high`, `critical`. Confidence
is `measured` (savings derived from real token counts) or `heuristic`
(behavioural impact, savings reported as `0`).

| ID                                    | Default severity         | Confidence | Trigger                                                                                                          | Recommendation summary                                                                              | Ref         |
|---------------------------------------|--------------------------|------------|------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|-------------|
| `kitchen-sink-system-prompt`          | scaled* (≥800/1500/3000) | measured   | `.github/copilot-instructions.md` exceeds 500 tokens.                                                            | Cut to smallest behaviour-changing rules; push detail into on-demand skills.                        | Ch 14 #1    |
| `verbose-auto-generated-instructions` | scaled* (≥1500/3000/6000)| measured   | Any `.github/instructions/**/*.instructions.md` ≥ 800 tokens (also flags `auto-generated`/`do not edit` markers).| Tighten `applyTo` glob, split files, or summarise.                                                  | Ch 14 #2    |
| `possible-policy-tension`             | `info`                   | heuristic  | Co-occurring opposites in `copilot-instructions.md` (e.g. `concise` + `detailed`, `never use` + `always use`).   | Heuristic only — pick a single voice if unintended.                                                 | Ch 14 #3    |
| `mcp-overload`                        | scaled† (≥5/10/20)       | measured / heuristic‡ | An MCP config (`.copilot/mcp-config.json`, `.vscode/mcp.json`, `.cursor/mcp.json`) declares ≥5 servers OR ≥30 tools. | Disable unused servers; ship a smaller default catalog.                                             | Ch 14 #4    |
| `mcp-config-unparseable`              | `warn`                   | measured   | An MCP config exists but is not valid JSON.                                                                      | Fix or remove; an unparseable config silently disables tool inventory measurement.                  | Ch 14 #4    |
| `verbose-tool-descriptions`           | `warn`                   | measured   | Any single MCP tool `description` exceeds 100 tokens.                                                            | Compress to one or two sentences; description is sent every step.                                   | Ch 14 #5    |
| `reasoning-leakage`                   | `high`                   | heuristic  | Always-on file contains `step by step`, `chain of thought`, `show your reasoning`, etc.                          | Reasoning is billed at output rate; make it opt-in per task.                                        | Ch 14 #11   |
| `polite-filler`                       | `warn`                   | heuristic  | Always-on file contains `be polite`, `be friendly`, `thank the user`, `start every response with`, etc.          | Cut filler; UX layer can re-add where needed.                                                       | Ch 14 #12   |
| `format-inflation`                    | `warn`                   | heuristic  | Always-on file contains `always use tables`, `always include emoji`, `show full output`, `always summarise`, etc.| Make rich formatting opt-in; default to compact.                                                    | Ch 14 #13   |
| `huge-agents-md`                      | scaled* (≥1500/3000/6000)| measured   | `AGENTS.md` or `.github/AGENTS.md` ≥ 800 tokens.                                                                 | Trim to landmines and conventions; push how-tos into on-demand docs.                                | Ch 14 #1    |

\* `severityForTokens(n, warn, high, crit)` — `info` below `warn`,
`warn`/`high`/`critical` at the named token thresholds.
† `severityForCount(serverCount + toolCount/10, 5, 10, 20)`.
‡ `mcp-overload` confidence is `measured` when the static config enumerates
tools, otherwise `heuristic` (the host-discovered runtime catalog cannot
be measured from the file alone).

## Output

### `--format text` (default)

```text
tokopt detect  <N> finding(s)

[<SEVERITY>] <Title> (<id>, <confidence>)
  location: <relative path or comma-separated list>
  evidence: <measured numbers or matched substrings>
  fix:      <recommendation>
  saves:    up to ~<N> tokens (<estimate basis>)        # measured findings only
  impact:   <basis>                                      # heuristic findings only
  ref:      Ch 14 #<n>
```

If no anti-patterns are found:

```text
tokopt detect: no anti-patterns found
```

### `--format json`

A JSON array of `Finding` objects:

| Field              | Type   | Description                                              |
|--------------------|--------|----------------------------------------------------------|
| `id`               | string | Detector ID (see table above).                           |
| `title`            | string | Human-readable title.                                    |
| `severity`         | string | `info` / `warn` / `high` / `critical`.                   |
| `confidence`       | string | `measured` / `heuristic`.                                |
| `location`         | string | Relative path(s) of the offending file.                  |
| `evidence`         | string | What the detector measured or matched.                   |
| `recommendation`   | string | Suggested fix.                                           |
| `est_tokens_saved` | int    | `0` for heuristic findings.                              |
| `estimate_basis`   | string | Free text explaining how `est_tokens_saved` was derived. |
| `chapter_ref`      | string | Reference to the corresponding guide chapter.            |

### `--format md`

Markdown `## Title (id) — severity / confidence` blocks per finding.

## Exit codes

| Code | Meaning                                                                              |
|------|--------------------------------------------------------------------------------------|
| 0    | Detectors ran (regardless of how many findings were produced).                        |
| 1    | I/O error or invalid flag (e.g. `--format=xml`).                                      |

`detect` never exits non-zero on findings. For CI gating, use
[`report --threshold`](report.md).

## Examples

Run against the current repo:

```bash
tokopt detect
```

Run against a specific subdirectory and show JSON:

```bash
tokopt detect ./examples/github-workflows --format json | jq '.[].id'
```

Filter to high-severity findings only:

```bash
tokopt detect --format json | jq '.[] | select(.severity == "high" or .severity == "critical")'
```

Markdown for a PR comment:

```bash
tokopt detect --format md > detect.md
```

## Notes

- Detectors that depend on usage telemetry (history blow-up, pasted blob
  persistence, tool-result echo) live in [`tail`](tail.md), not here.
- Heuristic findings (`possible-policy-tension`, `reasoning-leakage`,
  `polite-filler`, `format-inflation`) report `est_tokens_saved: 0` because
  their cost is on the **output** side and is not measurable from static
  config. Quantify them with `tail` against real usage logs.
- `mcp-overload` and `verbose-tool-descriptions` measure the static MCP
  config; the runtime tool catalog injected by the host is server-dependent
  and not visible to tokopt.

## See also

- [`audit`](audit.md) — static config token totals (no findings).
- [`report`](report.md) — `audit` + `detect` combined, with threshold gate.
- [`tail`](tail.md) — surface heavy-tail outliers in usage logs.
- [`../concepts/always-on-tax.md`](../concepts/always-on-tax.md)
- [`../reference/exit-codes.md`](../reference/exit-codes.md)
