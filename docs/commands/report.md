# `tokopt report`

Combined `audit` + `detect` dashboard with ranked recommendations and a
CI-friendly token-budget gate.

## Synopsis

```bash
tokopt report [path] [--threshold N] [--reference-window N] \
              [--format text|json|md] [--encoding o200k_base|cl100k_base]
```

## Description

Runs both [`audit`](audit.md) and [`detect`](detect.md) against `path`
(default `.`), merges their results into a single payload, ranks
**measured** recommendations by estimated tokens saved (descending), and
keeps **heuristic** findings in a separate "quality findings" list so
the ranked numbers stay defensible.

When `--threshold N` is set and the audit's `always_on_total` exceeds
`N` (strict `>`), `report` writes its full output, then prints a
violation message to stderr and exits with **code 2**. This is the
intended CI gate.

## Arguments

| Name   | Required | Default | Description                            |
|--------|----------|---------|----------------------------------------|
| `path` | no       | `.`     | Directory to scan. Must be a directory. |

## Flags

| Flag                 | Type   | Default      | Description                                                                                                                |
|----------------------|--------|--------------|----------------------------------------------------------------------------------------------------------------------------|
| `--threshold`        | int    | `0`          | Always-on token budget. If `> 0` and `always_on_total > --threshold`, exit code 2. Gate applies to **always-on only** — conditional and on-demand totals are not budgeted. |
| `--encoding`         | string | `o200k_base` | Tokenizer encoding.                                                                                                        |
| `--format`           | string | `text`       | Output format: `text`, `json`, or `md`.                                                                                    |
| `--reference-window` | int    | `0`          | If `> 0`, audit also reports always-on tax as `% of <window>`.                                                             |

## Output

### `--format text` (default)

`report` first emits the [`audit`](audit.md#--format-text-default) text
block, then a blank line, then the [`detect`](detect.md#--format-text-default)
findings block, then two ranked lists:

```text
ranked recommendations (measured savings, highest impact first):
  1. (up to ~<N> tok)  <action>  [<id> @ <location>]
  2. (up to ~<N> tok)  <action>  [<id> @ <location>]
  ...

quality findings (heuristic — impact not measurable from static config):
  • <action>  [<id> @ <location>]
  ...
```

If `--threshold` was exceeded, an additional line is written **to stderr**
(stdout still contains the full report):

```text
tokopt: always-on tax <N> exceeds threshold <T>
```

### `--format json`

Top-level object:

| Field              | Type   | Description                                                       |
|--------------------|--------|-------------------------------------------------------------------|
| `audit`            | object | Full audit result (see [`audit --format json`](audit.md#--format-json)). |
| `findings`         | array  | Full anti-pattern findings (see [`detect --format json`](detect.md#--format-json)). |
| `recommendations`  | array  | Measured recommendations sorted by `est_tokens_saved` desc.        |
| `quality_findings` | array  | Heuristic recommendations (`est_tokens_saved == 0`); omitted when empty. |

Each `recommendations[]` / `quality_findings[]` entry:

| Field              | Type   | Description                                       |
|--------------------|--------|---------------------------------------------------|
| `id`               | string | Originating finding ID.                           |
| `action`           | string | Recommended fix (mirrors finding's `recommendation`). |
| `est_tokens_saved` | int    | `0` for quality findings.                         |
| `estimate_basis`   | string | How the saved estimate was derived.               |
| `source`           | string | File path the recommendation refers to.           |

### `--format md`

Markdown rendering of the same data: audit table, findings sections,
"ranked recommendations (measured)" table, and a "quality findings
(heuristic)" bullet list.

## Exit codes

| Code | Meaning                                                                                                  |
|------|----------------------------------------------------------------------------------------------------------|
| 0    | Report written; no threshold was set, or `always_on_total ≤ --threshold`.                                |
| 1    | I/O error, invalid flag (e.g. `--format=xml`), or any underlying audit/detect failure.                   |
| 2    | `--threshold > 0` **and** `always_on_total > --threshold`. Stdout still contains the full report; stderr has the violation message. |

> [!IMPORTANT]
> The threshold uses **strict greater-than**: `always_on_total == threshold`
> passes (exit 0). The gate is on the always-on total only — conditional
> and on-demand totals never trip exit code 2.

## Examples

Local human-readable report:

```bash
tokopt report
```

CI gate: fail the pipeline if always-on tax exceeds 1500 tokens:

```bash
tokopt report --threshold 1500
```

Persist the JSON report as a CI artefact and still gate on threshold:

```bash
tokopt report --threshold 1500 --format json > report.json
echo "exit=$?"
```

Markdown for a sticky PR comment:

```bash
tokopt report --format md > report.md
gh pr comment "$PR" --body-file report.md
```

Express always-on tax as a percentage of a 128k window in the same run:

```bash
tokopt report --reference-window 128000 --threshold 2000
```

GitHub Actions step (fail the job on budget overrun, upload the report):

```yaml
- name: tokopt budget gate
  run: |
    tokopt report --threshold 1500 --format md > tokopt-report.md
- name: Upload report
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: tokopt-report
    path: tokopt-report.md
```

## Notes

- `report` runs the **same** scanners as `audit` and `detect`; results
  are byte-identical for the audit/findings sections. The added value
  is the ranked recommendations and the threshold gate.
- Heuristic findings are intentionally segregated into `quality_findings`
  so the ranked list never mixes measured savings with behavioural ones.
- The threshold message goes to **stderr**, the report goes to **stdout**.
  This means CI logs surface the violation independently from a stdout
  redirect.
- Use [`audit`](audit.md) for human exploration with no gate; use
  [`report`](report.md) for the same data with CI semantics.

## See also

- [`audit`](audit.md) — same totals, no findings, no gate.
- [`detect`](detect.md) — same findings, no totals, no gate.
- [`tail`](tail.md) — runtime telemetry view (paired with `report` for full picture).
- [`../use-cases/ci-budget-gating.md`](../use-cases/ci-budget-gating.md)
- [`../reference/exit-codes.md`](../reference/exit-codes.md)
