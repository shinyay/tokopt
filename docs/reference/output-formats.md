# Output formats

Most `tokopt` commands select presentation with the persistent `--format`
flag. Raw Rewind content, JSONL transcript streams, shell completion, version,
and help have command-specific contracts. The authoritative command matrix,
wire shapes, and audited exceptions live in the source repo's
[CLI JSON schema](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/tools/tokopt/docs/cli-json-schema.md).

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

Versioned JSON documents carry `"format_version": "v1"`. Most are
pretty-printed with 2-space indentation; compact primitives and legacy Rewind
success payloads are documented as exceptions in the canonical schema.

### `tokopt audit --format json`

```json
{
  "format_version": "v1",
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
  "format_version": "v1",
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

A versioned object whose `findings` field contains the finding array:

```json
{
  "format_version": "v1",
  "findings": [
    {
      "id": "string",
      "title": "string",
      "severity": "info | warn | high | critical",
      "confidence": "measured | heuristic",
      "location": "string (optional)",
      "evidence": "string (optional)",
      "recommendation": "string",
      "est_tokens_saved": 0,
      "estimate_basis": "string (optional)",
      "chapter_ref": "string (optional)"
    }
  ]
}
```

When no findings are present, `findings` is `null` or `[]` (consumers should
accept either). `est_tokens_saved == 0` means the finding is a quality
heuristic; impact isn't measurable from static config.

### `tokopt tail --format json`

```json
{
  "format_version": "v1",
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
  "format_version": "v1",
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

When `--threshold` is exceeded, the same single document also includes:

```json
{
  "status": "budget_exceeded",
  "details": {
    "threshold": 800,
    "always_on_total": 950,
    "excess_tokens": 150
  }
}
```

The process exits `2`; stdout ends after this report document and the
human diagnostic is written to stderr.

### `tokopt slim --format json`

Single-file and batch slim results are versioned objects. Transformed content
is intentionally omitted from JSON; use text/Markdown output for the body.
When a destructive safety check refuses after the result has been computed,
stdout still contains exactly one result document and the diagnostic goes to
stderr. A JSON/YAML format-change refusal records:

```json
{
  "format_version": "v1",
  "apply": {
    "wrote": false,
    "reason": "format-change-not-allowed"
  }
}
```

The process exits `2`. Add `--allow-format-change` only when replacing
JSON/YAML with another media type is intentional (normally TOON; YAML
Ionizer output can remain JSON if TonForm skips). `--force` cannot bypass
this gate.

Safety-preserving structured skips may add:

```json
{
  "diagnostics": [
    {
      "stage": "TonForm",
      "code": "number_fidelity",
      "message": "TonForm: ..."
    }
  ]
}
```

Stable codes are `duplicate_key`, `number_fidelity`,
`unsupported_structure`, and `invalid_structure`.

### `tokopt rewind verify --format json`

Single-hash and full-store verification emit one versioned object. A corrupted
`--all` result remains the sole stdout document and exits `2`:

```json
{
  "format_version": "v1",
  "ok": false,
  "verified": 3,
  "corrupted": ["0123456789abcdef..."]
}
```

### `tokopt chat-compact --format json`

Read-only and apply modes emit one versioned summary object to stdout. If an
apply safety check refuses, the same object records `apply.wrote: false` and a
stable reason; stderr carries the diagnostic and the process exits non-zero.

### `tokopt count`

```json
{ "format_version": "v1", "path": "README.md", "encoding": "o200k_base", "tokens": 1284, "bytes": 5421 }
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

`tokopt` is currently at **v0.18.0**. Versioned JSON documents use
`format_version: "v1"`; additive fields may appear without a format bump,
while incompatible wire changes require a new format version. Until v1.0:

- **Accept additive fields.** Consumers should ignore fields they do not
  understand and fail closed on an unknown `format_version`.
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
