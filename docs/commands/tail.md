# `tokopt tail`

Heavy-tail percentile analysis of a token-usage log. Surfaces the
expensive outliers that drive most of your bill — even when the median
call looks fine.

## Synopsis

```bash
tokopt tail --input FILE [--column NAME] [--top N] \
            [--format text|json|md] [--encoding o200k_base|cl100k_base]
```

## Description

Reads a usage log (one record per line) and reports `mean / p50 / p90 /
p95 / p99 / max`, the share of total tokens contributed by the top 1% of
records (or the single largest, on small samples), the top-N outlier
records themselves, and a heavy-tail hint when the distribution is
visibly skewed.

`tail` is the runtime counterpart to `detect`: where `detect` reads
static config, `tail` reads what was actually paid for.

## Arguments

None. All input is via flags.

## Flags

| Flag        | Type   | Default   | Required | Description                                                                                       |
|-------------|--------|-----------|----------|---------------------------------------------------------------------------------------------------|
| `--input`   | string | —         | yes      | Path to JSONL/NDJSON or CSV file. Use `-` for stdin (treated as JSONL).                           |
| `--column`  | string | `tokens`  | no       | JSON field or CSV header name that holds the token count per record.                              |
| `--top`     | int    | `5`       | no       | Number of outlier records to surface in the report.                                               |

Persistent flags also apply: `--encoding` (no effect on `tail`),
`--format` (`text`, `json`, `md`).

## Input format

Format is detected from the filename suffix:

| Suffix           | Parser  |
|------------------|---------|
| `.jsonl`         | JSONL   |
| `.ndjson`        | JSONL   |
| `.csv`           | CSV     |
| `-` (stdin)      | JSONL   |

Anything else fails with `unsupported format for "<file>"`.

### JSONL

One JSON object per line. Records without the `--column` field are
**silently skipped**. Records with non-numeric values are skipped.
Strings that look like integers (`"1234"`) are accepted.

```jsonl
{"timestamp":"2026-04-29T08:12:04Z","session":"s-001","turn":1,"prompt_tokens":820,"completion_tokens":140,"tokens":960}
{"timestamp":"2026-04-29T08:18:33Z","session":"s-001","turn":2,"prompt_tokens":880,"completion_tokens":210,"tokens":1090}
```

### CSV

First row must be the header. The `--column` lookup is case-insensitive
and trims whitespace. Rows whose chosen column is empty or non-numeric
are silently skipped.

## Output

### `--format text` (default)

```text
tokopt tail  source=<path>  format=<jsonl|csv>  column=<name>  records=<N>

  mean: <F>  p50: <N>  p90: <N>  p95: <N>  p99: <N>  max: <N>
  <top 1% of records|single largest record> account(s) for <P>% of total tokens
  hint: the top 1% of records account for >30% of total tokens — investigate the outliers above (Ch 13 heavy tail)

outliers:
  1. <N> tokens — <key=value key=value …>
  2. <N> tokens — …
```

The `hint:` line appears only when ≥ 100 records and top-1% share > 30%.

### `--format json`

| Field                | Type    | Description                                                                                  |
|----------------------|---------|----------------------------------------------------------------------------------------------|
| `source`             | string  | Echo of `--input` (`-` for stdin).                                                           |
| `format`             | string  | `"jsonl"` or `"csv"`.                                                                        |
| `column`             | string  | Echo of `--column`.                                                                          |
| `count`              | int     | Number of records that contributed a numeric token count.                                    |
| `sum`                | int     | Total tokens across all records.                                                             |
| `mean`               | float   | `sum / count`.                                                                               |
| `p50`                | int     | Median (note JSON key is `p50`, not `median`).                                               |
| `p90`                | int     | 90th percentile.                                                                             |
| `p95`                | int     | 95th percentile.                                                                             |
| `p99`                | int     | 99th percentile.                                                                             |
| `max`                | int     | Largest observed value.                                                                      |
| `top_share_pct`      | float   | Share of total tokens contributed by `top_share_label`'s slice.                              |
| `top_share_label`    | string  | `"top_1pct_share"` (≥ 100 records) or `"top_record_share"` (smaller samples).                |
| `top_records`        | array   | Top-N records by token count: `{ tokens, raw }` where `raw` is the original parsed object.   |
| `heavy_tail_hint`    | string  | Present only when ≥ 100 records and `top_share_pct > 30`.                                    |

Percentiles use nearest-rank: `index = ceil(p * count) - 1` (clamped).

### `--format md`

Markdown table of the metrics above and an optional blockquote for the
heavy-tail hint.

## Exit codes

| Code | Meaning                                                                                       |
|------|-----------------------------------------------------------------------------------------------|
| 0    | Analysis succeeded.                                                                           |
| 1    | `--input` missing; file unreadable; unsupported format; no records with a numeric token count; negative token count; CSV header missing the requested column. |

## Examples

Analyse a JSONL log shipped from your host:

```bash
tokopt tail --input usage.jsonl
```

Analyse a CSV exported from a billing dashboard, using a non-default column:

```bash
tokopt tail --input usage.csv --column total_tokens --top 10
```

Stream from stdin (`-` is treated as JSONL):

```bash
gh api repos/me/repo/issues | jq -c '.[] | {tokens: (.body|length)}' | tokopt tail --input -
```

Get a JSON view for further processing:

```bash
tokopt tail --input usage.jsonl --format json | jq '.p99, .top_share_pct'
```

Markdown summary for a PR comment:

```bash
tokopt tail --input usage.jsonl --format md > tail.md
```

## Notes

- The percentile computation is exact (nearest-rank), not an estimate.
- For small samples (< 100 records) the "top share" line falls back to
  the **single largest record** so users do not read "top 1% = 50%" off
  two rows. The label changes accordingly.
- Records missing the configured column are silently skipped; this lets
  you pipe heterogeneous logs in directly.
- The raw record payload is preserved on every top-N entry, so downstream
  tools can group / drill in by `session`, `turn`, etc.
- Negative token counts are rejected as invalid usage data.

## See also

- [`detect`](detect.md) — static-config anti-patterns.
- [`audit`](audit.md) — static-config token tax.
- [`report`](report.md) — combined dashboard.
- [`../use-cases/monitoring-token-spend.md`](../use-cases/monitoring-token-spend.md)
- [`../reference/output-formats.md`](../reference/output-formats.md)
