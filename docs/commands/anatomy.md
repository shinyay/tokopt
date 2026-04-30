# `tokopt anatomy`

Decompose a hypothetical (or real) prompt into the **seven canonical
segments** and report per-segment token cost and share of the total
input.

## Synopsis

```bash
tokopt anatomy [--system FILE] [--always-on FILE] [--tools FILE] \
               [--history FILE] [--retrieved FILE] [--user FILE] \
               [--reasoning FILE] [--json FILE] \
               [--format text|json|md] [--encoding o200k_base|cl100k_base]
```

## Description

Anatomy reads zero-or-more files (one per segment) and reports tokens,
bytes, and `% of input` for each. It is the runtime counterpart of
[`audit`](audit.md): `audit` measures static config; `anatomy` measures
the assembled prompt.

The seven segments are: **system**, **always-on**, **tools**, **history**,
**retrieved**, **user**, **reasoning**.

You must provide at least one segment, either via the per-segment flags
or via `--json`. Segments that are not provided are reported as `0` and
are excluded from cross-segment warning checks.

## Arguments

None. All input is via flags.

## Flags

| Flag            | Type   | Default | Description                                                                                  |
|-----------------|--------|---------|----------------------------------------------------------------------------------------------|
| `--system`      | string | `""`    | Path to the system prompt content. Use `-` for stdin.                                        |
| `--always-on`   | string | `""`    | Path to always-on instruction content (e.g. `copilot-instructions.md`). Use `-` for stdin.   |
| `--tools`       | string | `""`    | Path to the tool / function catalog (text or JSON). Use `-` for stdin.                       |
| `--history`     | string | `""`    | Path to a conversation history transcript. Use `-` for stdin.                                |
| `--retrieved`   | string | `""`    | Path to retrieved context (RAG, file reads, search results). Use `-` for stdin.              |
| `--user`        | string | `""`    | Path to the current user message. Use `-` for stdin.                                         |
| `--reasoning`   | string | `""`    | Path to a reasoning scaffold (optional). Use `-` for stdin.                                  |
| `--json`        | string | `""`    | Path to a JSON object whose keys mirror the segment flag names. Use `-` for stdin.           |

> [!IMPORTANT]
> `--json` is a **path** to a JSON file (string), not a boolean toggle.
> When set, it takes precedence over the per-segment flags. Allowed keys:
> `system`, `always_on` (or `always-on`), `tools`, `history`, `retrieved`,
> `user`, `reasoning`. Unknown keys are rejected.

Persistent flags also apply: `--encoding`, `--format`. `--reference-window`
has no effect on `anatomy`.

Only one of `-` may be used across all flags in a single invocation
(stdin is consumed once).

## Output

### `--format text` (default)

```text
tokopt anatomy  encoding=<encoding>  total input=<N> tokens

SEGMENT    TOKENS  BYTES  % OF INPUT
system     <N>     <N>    <P>%
always-on  <N>     <N>    <P>%
tools      <N>     <N>    <P>%
history    <N>     <N>    <P>%
retrieved  <N>     <N>    <P>%
user       <N>     <N>    <P>%
reasoning  <N>     <N>    <P>%

warnings:
  • <message>
```

The `warnings:` block appears only when at least one warning fires.

### `--format json`

| Field                | Type   | Description                                          |
|----------------------|--------|------------------------------------------------------|
| `encoding`           | string | Tokenizer encoding name.                             |
| `segments[]`         | array  | One entry per segment (always all seven, in order).  |
| `segments[].name`    | string | Segment name.                                        |
| `segments[].tokens`  | int    | Token count.                                         |
| `segments[].bytes`   | int    | Raw byte length.                                     |
| `segments[].percent_of_input` | float | Percent of `total_input_tokens`.            |
| `total_input_tokens` | int    | Sum of all segment tokens.                           |
| `warnings`           | array  | Strings; omitted when empty.                         |

### `--format md`

Markdown header + table + optional warnings list.

## Warnings

Anatomy emits the following warnings when their comparator segments were
all supplied (otherwise the check is suppressed):

| Trigger                                                        | Message (excerpt)                                                                |
|----------------------------------------------------------------|----------------------------------------------------------------------------------|
| `user` provided, `user.tokens > 0`, `user.percent < 1.0`       | "user message is < 1% of input — your intent is a rounding error…"                |
| `system + always-on + tools` provided, sum > 50% of total      | "system+always-on+tools is > 50% of input — most of every call is overhead…"      |
| `history` provided, `history.percent > 40`                     | "history is > 40% of input — consider truncating or summarising old turns…"       |
| `reasoning` provided, `reasoning.percent > 20`                 | "reasoning scaffold is > 20% of input — confirm this depth is needed…"            |
| Any segment missing                                            | "partial input — cross-segment ratios involving missing segments were skipped…"   |

## Exit codes

| Code | Meaning                                                          |
|------|------------------------------------------------------------------|
| 0    | Analysis written. Warnings do **not** affect the exit code.       |
| 1    | I/O error, no segments provided, or invalid JSON / unknown key.   |

## Examples

Single user message in isolation (sanity check):

```bash
tokopt anatomy --user examples/user-message.txt
```

The repo's quickstart demo (~481 input tokens for the sample data):

```bash
tokopt anatomy \
  --always-on examples/always-on.txt \
  --user      examples/user-message.txt
```

Pipe a transcript via stdin and combine with files on disk:

```bash
git log -p | tokopt anatomy --history - --user message.txt --tools tools.json
```

JSON-driven invocation (one file, all segments):

```bash
cat > prompt.json <<'JSON'
{
  "system":    "You are a helpful assistant.",
  "always-on": "Project rules: ...",
  "tools":     "...",
  "user":      "Refactor handleClick"
}
JSON
tokopt anatomy --json prompt.json --format json
```

Markdown table for a PR comment:

```bash
tokopt anatomy --json prompt.json --format md > anatomy.md
```

## Notes

- Files are read as raw bytes and tokenized as one string. Anatomy does
  no framing-aware parsing — what you put in a file is what is counted.
- Percentages are computed against the **sum of provided segments**, not
  against any external context-window size. Combine with
  `--reference-window` on [`audit`](audit.md) if you need a
  window-relative view.
- Stdin (`-`) can be used for at most one segment per invocation.

## See also

- [`audit`](audit.md) — static repo configuration.
- [`count`](count.md) — single-file token count.
- [`detect`](detect.md) — anti-patterns in static config.
- [`../concepts/token-vocabulary.md`](../concepts/token-vocabulary.md)
- [`../reference/output-formats.md`](../reference/output-formats.md)
