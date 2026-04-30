# `tokopt audit`

Scan a repository for static Copilot/agent configuration and report the
**token tax** every interaction pays — broken down into always-on,
conditional, and on-demand scopes.

## Synopsis

```bash
tokopt audit [path] [--reference-window N] [--format text|json|md] [--encoding o200k_base|cl100k_base]
```

## Description

Walks the repo under `path` (default `.`), classifies each
Copilot-relevant configuration file by **scope** (when it is paid for),
counts its tokens, and prints both totals and a per-file breakdown.

`audit` is read-only and informational. It does **not** fail on a budget
overrun — that is the job of [`report --threshold`](report.md). Use
`audit` for human exploration; use `report` for CI gating.

## Arguments

| Name     | Required | Default | Description                                  |
|----------|----------|---------|----------------------------------------------|
| `path`   | no       | `.`     | Directory to scan. Must be a directory.      |

## Flags

`audit` has no flags of its own. It honours the persistent flags:

| Flag                  | Type   | Default       | Description                                              |
|-----------------------|--------|---------------|----------------------------------------------------------|
| `--encoding`          | string | `o200k_base`  | Tokenizer encoding (`o200k_base` or `cl100k_base`).      |
| `--format`            | string | `text`        | Output format: `text`, `json`, or `md`.                  |
| `--reference-window`  | int    | `0`           | If `> 0`, also reports the always-on tax as a percentage of this token-window size. Opt-in only. |

> [!NOTE]
> `audit` does **not** accept `--threshold`. Token-budget gating lives on
> [`report`](report.md).

## Files audited

Files are discovered by exact path or glob, then classified:

| Path / glob                                  | Category                | Scope         |
|----------------------------------------------|-------------------------|---------------|
| `.github/copilot-instructions.md`            | `copilot-instructions`  | `always-on`   |
| `AGENTS.md`                                  | `agents-md`             | `always-on`   |
| `.github/AGENTS.md`                          | `agents-md`             | `always-on`   |
| `.github/instructions/**/*.instructions.md`  | `scoped-instructions`   | `conditional` |
| `.copilot/mcp-config.json`                   | `mcp-config`            | `conditional` |
| `.vscode/mcp.json`                           | `mcp-config`            | `conditional` |
| `.cursor/mcp.json`                           | `mcp-config`            | `conditional` |
| `agents/**/*.agent.md`                       | `agent-definition`      | `conditional` |
| `.github/agents/**/*.agent.md`               | `agent-definition`      | `conditional` |
| `skills/*/SKILL.md`                          | `skill-definition`      | `on-demand`   |
| `.github/skills/*/SKILL.md`                  | `skill-definition`      | `on-demand`   |

`mcp-config` files are re-marshalled compactly (whitespace-stripped) before
counting, so the measured tokens approximate what a host actually serialises.

## Output

### `--format text` (default)

```text
tokopt audit  root=<path>  encoding=<encoding>
always-on tax: <N> tokens [(<P>% of <W>-token reference window)]
conditional:   <N> tokens (paid only when triggered: applyTo, agent step, agent invoked)
on-demand:     <N> tokens (skills loaded only when matched)

TOKENS  BYTES  SCOPE        CATEGORY              PATH                                  NOTE
<N>     <N>    always-on    copilot-instructions  .github/copilot-instructions.md
<N>     <N>    conditional  scoped-instructions   .github/instructions/foo.instructions.md  loaded only for matching files (applyTo glob)
...
```

The reference-window line appears only when `--reference-window > 0`.

### `--format json`

Top-level object, schema:

| Field                | Type     | Description                                         |
|----------------------|----------|-----------------------------------------------------|
| `root`               | string   | Audit root path.                                    |
| `encoding`           | string   | Active tokenizer encoding.                          |
| `files`              | array    | Per-file records (see below).                       |
| `always_on_total`    | int      | Sum of tokens with scope `always-on`.               |
| `conditional_total`  | int      | Sum of tokens with scope `conditional`.             |
| `on_demand_total`    | int      | Sum of tokens with scope `on-demand`.               |
| `per_category_total` | object   | `{ category → tokens }`.                            |
| `per_scope_total`    | object   | `{ scope → tokens }`.                               |
| `reference_window`   | int      | Echo of `--reference-window` (omitted if 0).        |
| `window_percent`     | float    | `always_on_total / reference_window * 100` (omitted if 0). |

Each `files[]` entry: `{ path, category, scope, tokens, bytes, note? }`.

### `--format md`

Same data as `text`, rendered as a Markdown header + list + table.

## Exit codes

| Code | Meaning                                                                   |
|------|---------------------------------------------------------------------------|
| 0    | Audit completed; results written.                                         |
| 1    | I/O error (root not a directory, unreadable file) or invalid flag value.  |

## Examples

Audit the current repo:

```bash
tokopt audit
```

Audit a specific path:

```bash
tokopt audit ./examples/github-workflows
```

Express the always-on tax as a percentage of a 128k context window:

```bash
tokopt audit --reference-window 128000
```

Emit JSON for a dashboard or downstream tool:

```bash
tokopt audit --format json > audit.json
jq '.always_on_total, .per_scope_total' audit.json
```

Emit Markdown for a PR comment:

```bash
tokopt audit --format md > audit.md
```

## Notes

- Files that do not exist are silently skipped — there is no error if a
  repo lacks (e.g.) an `AGENTS.md`.
- The audit measures **static file size**. Conditional files have a
  runtime cost that is bounded above by the measured number; on-demand
  skills only count when triggered.
- `--reference-window` is purely a display aid: tokopt never bakes in a
  default model-window size.

## See also

- [`report`](report.md) — same data + anti-patterns + CI threshold gate.
- [`detect`](detect.md) — anti-pattern findings only.
- [`anatomy`](anatomy.md) — per-prompt segment cost (run-time view).
- [`../concepts/three-layer-model.md`](../concepts/three-layer-model.md) — always-on vs conditional vs on-demand.
- [`../reference/cli-reference.md`](../reference/cli-reference.md)
