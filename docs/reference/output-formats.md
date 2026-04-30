# Output formats

Every `tokopt` command writes to stdout in one of three formats,
selected by the persistent `--format` flag. This page documents the
full payload schema each command emits.

## The three formats

| Format | Best for                          | Audience |
|--------|-----------------------------------|----------|
| `text` | Terminals, screenshots, README snippets. Default. | Humans. |
| `json` | Scripts, CI, ingestion into other tools (jq, dashboards, alerts). | Machines. |
| `md`   | PR comments, doc embeds, GitHub issue bodies. | Humans, but rendered. |

`--format` is validated at startup. Any value other than `text`,
`json`, or `md` exits `1`:

```text
error: unsupported --format "yaml" (allowed: text, json, md)
```

## Choosing a format

| Use case                                | Pick   |
|-----------------------------------------|--------|
| Local debugging, screenshots            | `text` |
| Bash one-liners with `jq`               | `json` |
| Posting a PR comment from CI            | `md`   |
| Storing artefacts for diffing over time | `json` |
| Dropping into a GitHub issue body       | `md`   |

## Setting the format

```bash
tokopt audit  . --format json
tokopt detect . --format md
tokopt report . --format json --threshold 800
```

Default (no flag): `text`.

---

## Per-command output schemas

All JSON output is pretty-printed with 2-space indentation. Field names
are stable within a minor version (see *Stable vs unstable fields* below).

### `tokopt audit --format json`

```json
{
  "root": "string",
  "encoding": "o200k_base",
  "files": [
    {
      "path": "string",
      "category": "string",
      "scope": "string",
      "tokens": 0,
      "bytes": 0,
      "note": "string (optional)"
    }
  ],
  "always_on_total": 0,
  "conditional_total": 0,
  "on_demand_total": 0,
  "per_category_total": { "category-name": 0 },
  "per_scope_total":    { "scope-name": 0 },
  "reference_window": 0,
  "window_percent": 0.0
}
```

`reference_window` and `window_percent` are present only when
`--reference-window > 0`.

### `tokopt anatomy --format json`

```json
{
  "encoding": "o200k_base",
  "segments": [
    {
      "name": "system",
      "tokens": 0,
      "percent_of_input": 0.0,
      "bytes": 0
    }
  ],
  "total_input_tokens": 0,
  "warnings": ["string"]
}
```

`warnings` is omitted when empty. Segments are emitted in canonical
order: `system`, `always_on`, `tools`, `history`, `retrieved`, `user`,
`reasoning`.

#### `--json` is **input**, not output

Despite the name, `anatomy --json PATH` is an *input* mechanism: a path
to a JSON object describing where to find the seven segments. It is
**not** an output-format toggle — output is governed by `--format`.

Input schema for `--json`:

```json
{
  "system":     "path/or/-",
  "always_on":  "path/or/-",
  "tools":      "path/or/-",
  "history":    "path/or/-",
  "retrieved":  "path/or/-",
  "user":       "path/or/-",
  "reasoning":  "path/or/-"
}
```

Both `always_on` and `always-on` are accepted. Unknown keys are
rejected with exit code `1`. All values must be strings (paths). Use
`-` for stdin (only one segment may use `-` per invocation).

### `tokopt detect --format json`

A JSON **array** of finding objects (top-level array, not wrapped):

```json
[
  {
    "id": "string",
    "title": "string",
    "severity": "info | warn | high | critical",
    "confidence": "low | medium | high",
    "location": "string (optional)",
    "evidence": "string (optional)",
    "recommendation": "string",
    "est_tokens_saved": 0,
    "estimate_basis": "string (optional)",
    "chapter_ref": "string (optional)"
  }
]
```

When no findings are present, the array is `null` or `[]` (consumers
should accept either). `est_tokens_saved == 0` means the finding is a
quality heuristic; impact isn't measurable from static config.

### `tokopt tail --format json`

```json
{
  "source": "string",
  "format": "jsonl | csv",
  "column": "tokens",
  "count": 0,
  "sum": 0,
  "mean": 0.0,
  "p50": 0,
  "p90": 0,
  "p95": 0,
  "p99": 0,
  "max": 0,
  "top_share_pct": 0.0,
  "top_share_label": "top_1pct_share | top_record_share",
  "top_records": [
    { "tokens": 0, "raw": { "any": "fields" } }
  ],
  "heavy_tail_hint": "string (optional)"
}
```

`top_share_label` is `top_record_share` for very small datasets where
the "top 1%" rounds to a single record; otherwise `top_1pct_share`.
`raw` carries the original record fields (truncated for display in
`text`/`md`, complete in `json`).

### `tokopt report --format json`

The combined dashboard. Embeds the audit payload verbatim and adds
findings + ranked recommendations:

```json
{
  "audit":    { "...": "see audit schema above" },
  "findings": [ { "...": "see detect schema above" } ],
  "recommendations": [
    {
      "id": "string",
      "action": "string",
      "est_tokens_saved": 0,
      "estimate_basis": "string (optional)",
      "source": "string"
    }
  ],
  "quality_findings": [
    {
      "id": "string",
      "action": "string",
      "est_tokens_saved": 0,
      "estimate_basis": "string (optional)",
      "source": "string"
    }
  ]
}
```

`recommendations` contains only findings with `est_tokens_saved > 0`,
sorted descending by estimated savings. `quality_findings` (omitted
when empty) holds heuristic findings whose impact is not measurable
from static config.

### `tokopt count`

```json
{ "path": "README.md", "encoding": "o200k_base", "tokens": 1284, "bytes": 5421 }
```

Single-line, **not** pretty-printed (this is the only command that
deviates — the payload is small enough that one line is friendlier in
shell pipelines).

> [!NOTE]
> **Known limitation.** `count`'s renderer only branches on `json` vs
> default. If you pass `--format md`, the global validator accepts it
> but the command falls back to **text** output. If you need markdown
> for `count`, wrap it yourself or use `audit` / `report` whose `md`
> renderers are full implementations.

---

## Markdown format

`--format md` is most useful when the output will be read inside a
rendered surface — a PR comment, a GitHub issue, a docs page. Each
command emits a top-level heading, a bullet summary, and one or more
tables.

Example (`tokopt audit . --format md`):

```md
# tokopt audit

- root: `.`
- encoding: `o200k_base`
- **always-on tax: 742 tokens**
- conditional: 1284 tokens
- on-demand: 0 tokens

| Tokens | Bytes | Scope | Category | Path | Note |
|---:|---:|---|---|---|---|
| 312 | 1421 | always-on | instructions | `.github/copilot-instructions.md` |  |
| 430 | 2014 | always-on | agents       | `AGENTS.md`                       |  |
```

A common CI pattern is to capture this and post it as a PR comment:

```bash
tokopt report . --format md > tokopt-report.md
gh pr comment "$PR_NUMBER" --body-file tokopt-report.md
```

## Stable vs unstable fields

`tokopt` is at **v0.1.0**. JSON field names are not yet guaranteed
stable across minor releases — they will be by **v1.0**. Until then:

- **Treat field names as best-effort.** New fields may appear; existing
  fields are unlikely to disappear, but may be renamed before v1.0.
- **Pin the tokopt version in CI scripts.** Use a specific tag or
  release binary, not `latest`.
- **Don't depend on text output structure.** Tables, ordering, and
  wording in `text` and `md` may change between any two releases. For
  scripting, always use `--format json`.
- **Exit codes are stable.** Unlike field names, the `0` / `1` / `2`
  contract is part of the public API from v0.1.0 onward.

## See also

- [`cli-reference.md`](cli-reference.md) — full per-command flag tables.
- [`exit-codes.md`](exit-codes.md) — exit-code contract for CI.
- [`encodings.md`](encodings.md) — how `--encoding` interacts with output.
- [`../commands/`](../commands/) — long-form per-command docs with full output examples.
