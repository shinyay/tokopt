# CLI reference

Single-page consolidated reference for every `tokopt` command and flag.
Use this for printing or scanning; the per-command docs in
[`../commands/`](../commands/) are the long form.

## Synopsis

```text
tokopt <command> [flags] [args]
```

`tokopt` reads files (or stdin), counts tokens, and emits a structured
report. It never makes network calls and never reports dollars — only
tokens and percentages of an optional reference window.

## Global flags

These flags are persistent — every subcommand accepts them.

| Flag                  | Type   | Default       | Notes |
|-----------------------|--------|---------------|-------|
| `--encoding`          | string | `o200k_base`  | Tokenizer encoding. Valid: `o200k_base`, `cl100k_base`. See [`encodings.md`](encodings.md). |
| `--format`            | string | `text`        | Output format. Valid: `text`, `json`, `md`. Validated at startup. See [`output-formats.md`](output-formats.md). |
| `--reference-window`  | int    | `0` (off)     | If `> 0`, also expresses the always-on tax as a percentage of this window size. Used by `audit` and `report`. |
| `--version`           | —      | —             | Prints `tokopt version vX.Y.Z` and exits. Build-injected via `-ldflags`. |
| `--help`, `-h`        | —      | —             | Prints help for the root or any subcommand. Auto-added by cobra. |

## Commands at a glance

| Command   | One-liner                                                       | Per-command doc |
|-----------|-----------------------------------------------------------------|-----------------|
| `audit`   | Scan a repo's always-on Copilot config and report the token tax | [`audit.md`](../commands/audit.md) |
| `anatomy` | Decompose a prompt into the seven canonical segments            | [`anatomy.md`](../commands/anatomy.md) |
| `count`   | Count tokens in a single file (or stdin)                        | [`count.md`](../commands/count.md) |
| `detect`  | Run anti-pattern detectors against a repo's static config       | [`detect.md`](../commands/detect.md) |
| `report`  | Combined `audit` + `detect` dashboard with CI gate              | [`report.md`](../commands/report.md) |
| `tail`    | Heavy-tail percentile analysis of a usage log (JSONL or CSV)    | [`tail.md`](../commands/tail.md) |

---

## `tokopt audit`

Scan a repo for static Copilot/agent config and report the **token tax**
broken into always-on, conditional, and on-demand scopes.

```text
tokopt audit [path] [--reference-window N] [--format text|json|md] [--encoding ENC]
```

| Arg / Flag           | Default | Notes |
|----------------------|---------|-------|
| `path` (positional)  | `.`     | Repo root to scan. Optional. |
| `--reference-window` | `0`     | Inherited global; if set, adds `% of N-token window`. |
| `--format`           | `text`  | Inherited global. `text` / `json` / `md`. |
| `--encoding`         | `o200k_base` | Inherited global. |

**Exit codes**: `0` on success. `1` on I/O / parse errors. Never `2` —
`audit` does not gate; for CI, use [`report --threshold`](../commands/report.md).

See also: [`../commands/audit.md`](../commands/audit.md).

---

## `tokopt anatomy`

Decompose a hypothetical (or real) prompt into the seven canonical
segments: `system`, `always_on`, `tools`, `history`, `retrieved`,
`user`, `reasoning`.

```text
tokopt anatomy [--system PATH] [--always-on PATH] [--tools PATH]
               [--history PATH] [--retrieved PATH] [--user PATH]
               [--reasoning PATH]
               [--json PATH]                       # input bundle
               [--format text|json|md] [--encoding ENC]
```

| Flag           | Notes |
|----------------|-------|
| `--system`     | Path to system-prompt content (or `-` for stdin). |
| `--always-on`  | Path to always-on instruction content. |
| `--tools`      | Path to tool/function catalog (text or JSON). |
| `--history`    | Path to conversation history transcript. |
| `--retrieved`  | Path to retrieved context. |
| `--user`       | Path to current user message. |
| `--reasoning`  | Path to reasoning scaffold (optional). |
| `--json`       | **Input** path: a JSON object whose keys mirror the flag names (both `always_on` and `always-on` accepted; unknown keys rejected). Use `-` for stdin. **Not** an output toggle — output format is controlled by `--format`. |

**Exit codes**: `0` on success. `1` on I/O / parse errors (including
unknown keys in `--json`).

See also: [`../commands/anatomy.md`](../commands/anatomy.md).

---

## `tokopt count`

Count tokens in a single file (or stdin). The smallest primitive in
tokopt — useful in shell pipelines and ad-hoc checks.

```text
tokopt count <file> [--format text|json] [--encoding ENC]
```

| Arg / Flag   | Notes |
|--------------|-------|
| `<file>`     | Required positional. Use `-` for stdin. |
| `--format`   | `text` (default) or `json`. `md` is accepted globally but `count` falls back to `text`. See [`output-formats.md`](output-formats.md). |
| `--encoding` | Inherited global. |

**Exit codes**: `0` on success. `1` on I/O errors or invalid flags.

See also: [`../commands/count.md`](../commands/count.md).

---

## `tokopt detect`

Run anti-pattern detectors against a repo's static config and surface
each finding with severity, evidence, fix, and (when measurable)
estimated tokens saved.

```text
tokopt detect [path] [--format text|json|md] [--encoding ENC]
```

| Arg / Flag          | Default | Notes |
|---------------------|---------|-------|
| `path` (positional) | `.`     | Repo root to scan. Optional. |
| `--format`          | `text`  | Inherited global. |
| `--encoding`        | `o200k_base` | Inherited global. |

Findings carry severity `info` / `warn` / `high` / `critical` and
confidence `low` / `medium` / `high`.

**Exit codes**: **always `0` on success**, regardless of severity.
`1` on I/O / parse errors. Never `2`. Detection is *informational*; use
[`report --threshold`](../commands/report.md) to gate CI.

See also: [`../commands/detect.md`](../commands/detect.md).

---

## `tokopt report`

Combined `audit` + `detect` dashboard with ranked recommendations and a
CI-friendly token-budget gate.

```text
tokopt report [path] [--threshold N]
              [--reference-window N] [--format text|json|md] [--encoding ENC]
```

| Arg / Flag           | Default | Notes |
|----------------------|---------|-------|
| `path` (positional)  | `.`     | Repo root to scan. Optional. |
| `--threshold`        | `0`     | If `> 0`, exit with code **2** when the **always-on** tax `>` this token count. Strict greater-than: `==` passes. Gate covers always-on only — conditional and on-demand are not budgeted. |
| `--reference-window` | `0`     | Inherited global. |
| `--format`           | `text`  | Inherited global. |
| `--encoding`         | `o200k_base` | Inherited global. |

**Exit codes**: `0` on success and within budget. `1` on I/O / parse
errors. `2` when `--threshold` is set and always-on tax exceeds it.

See also: [`../commands/report.md`](../commands/report.md) and
[`exit-codes.md`](exit-codes.md).

---

## `tokopt tail`

Heavy-tail percentile analysis of a token-usage log. Surfaces the
expensive outliers that drive most of your bill — even when the median
call looks fine.

```text
tokopt tail --input PATH [--column NAME] [--top N]
            [--format text|json|md] [--encoding ENC]
```

| Flag         | Default  | Notes |
|--------------|----------|-------|
| `--input`    | (required) | Path to JSONL or CSV file. Use `-` for stdin. Format detected from extension and content. |
| `--column`   | `tokens` | Column (CSV) or JSON field name carrying the token count. |
| `--top`      | `5`      | Number of outlier records to surface in the report. |
| `--format`   | `text`   | Inherited global. |
| `--encoding` | `o200k_base` | Inherited but **unused** — `tail` reads counts, it does not tokenise. |

**Exit codes**: `0` on success. `1` on I/O / parse errors (missing
column, malformed JSONL, etc.). Never `2`.

See also: [`../commands/tail.md`](../commands/tail.md).

---

## Universal exit codes

| Code | Meaning                                                            | Triggered by |
|-----:|--------------------------------------------------------------------|--------------|
| `0`  | Success. No findings, or findings present but no gate. Within budget. | All commands on the happy path. |
| `1`  | Runtime error: file not found, parse error, unknown flag value, invalid `--encoding`, invalid `--format`, etc. | All commands. Message printed to stderr. |
| `2`  | Budget exceeded. Always-on tax `>` `--threshold`. | **Only** `tokopt report --threshold N` (strict `>`). |

The `1` vs `2` split matters in CI: `2` is a **policy** failure (your
config grew past the budget), `1` is an **operational** failure (the
tool itself couldn't run). Treat them differently in your pipeline. See
[`exit-codes.md`](exit-codes.md) for recipes.

## Output formats

`--format` is a persistent flag accepted by every command. The three
values are `text` (human-friendly default), `json` (machine-readable),
and `md` (markdown for embedding in PRs and docs). Schemas and
per-command quirks (notably `count`'s `md` fallback) are documented in
[`output-formats.md`](output-formats.md).

## Encodings

`--encoding` selects the BPE encoding used to count tokens. Only
`o200k_base` (default, GPT-4o family) and `cl100k_base` (legacy
GPT-3.5/4 family) are supported. Pick the one that matches your target
model family; the difference is typically 5–15% on the same input. See
[`encodings.md`](encodings.md).

## See also

- [`exit-codes.md`](exit-codes.md) — full exit-code matrix and CI recipes.
- [`output-formats.md`](output-formats.md) — JSON / markdown schemas.
- [`encodings.md`](encodings.md) — when to pick which tokenizer.
- [`../commands/`](../commands/) — per-command long-form documentation.
