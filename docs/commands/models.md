# `tokopt models`

List the models the active rate card can project cost for. Each entry
carries a `basis`: `empirical` (measured from real Copilot CLI sessions)
or `catalog` (derived from the official UBB input list price).

## Synopsis

```bash
tokopt models [--format text|json|md] [--credit-rates <rate-card.json>]
```

## Description

`tokopt models` answers the prerequisite to cost projection: **which
model names are valid for `--credit-model`?** It reads the active rate
card — the embedded default, or an external card supplied via
`--credit-rates` — and prints each model with its `basis` and per-input-token
rate.

The embedded card ships **19 models**: 4 empirically calibrated
(`gpt-5.5`, `claude-opus-4.7-1m-internal`, `gemini-3.1-pro-preview`,
`mai-code-1-flash-internal`) plus 15 catalog-derived from official GitHub
Copilot list prices. Catalog rates are a **conservative upper bound**
(full input price; no cache / output / reasoning discount).

The VS Code extension reads `tokopt models --format json` to populate its
model picker, so it always reflects the installed binary's card.

## Flags

`models` defines no flags of its own beyond `--credit-rates`. It honours
the persistent flags:

| Flag             | Type   | Default      | Description |
|------------------|--------|--------------|-------------|
| `--format`       | string | `text`       | Output format: `text`, `json`, or `md`. |
| `--credit-rates` | string | `""`         | Path to an external `rate-card.json`. When set, lists that card's models instead of the embedded default. |

## Output

### `--format text` (default)

```text
tokopt models  rate source=embedded  (19 models)
MODEL                        BASIS      NANO-AIU/TOK
claude-haiku-4.5             catalog    100000
claude-opus-4.7-1m-internal  empirical  621782
gpt-5.5                      empirical  312500
mai-code-1-flash-internal    empirical  75000
…
```

### `--format json`

```json
{
  "format_version": "v1",
  "rate_source": "embedded",
  "measured_at": "2026-06-05T23:40:33.054096+09:00",
  "models": [
    {"name": "claude-haiku-4.5", "rate_status": "ok", "basis": "catalog", "nano_aiu_per_input_token": 100000},
    {"name": "gpt-5.5", "rate_status": "ok", "basis": "empirical", "nano_aiu_per_input_token": 312500}
  ]
}
```

Entries are sorted by `name`. `rate_source` is `embedded` or
`external:<path>`.

The embedded v1 card is a static snapshot verified on **2026-06-06**, not a
live provider catalog. Use `measured_at` to judge freshness; missing newer
models or billing dimensions must not silently fall back to another rate.

### `--format md`

A markdown table (`| Model | Basis | nano-AIU / input token |`), handy for
pasting into a PR comment.

## Exit codes

| Code | Meaning |
|------|---------|
| `0`  | Success. |
| `1`  | A malformed or unreadable external `--credit-rates` card. |

## See also

- [`audit.md`](audit.md) — project a whole repo's token tax onto one of
  these models via `--credit-model`.
- [`count.md`](count.md) — project a single file; JSON gains a
  `rate_basis` field.
- [AIU & rate cards](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/website/docs/foundations/aiu-and-rate-cards.en.md)
  — methodology, the catalog-vs-empirical distinction, and how the merged
  embedded card is generated.
