# `tokopt count`

Count the tokens in a single file (or stdin). The smallest primitive in
tokopt — useful in shell pipelines and ad-hoc checks.

## Synopsis

```bash
tokopt count <file> [--format text|json] [--encoding o200k_base|cl100k_base]
```

## Description

Reads `<file>`, runs it through the configured tokenizer, and prints the
token count, byte count, and encoding name. The file is read as raw bytes
and treated as a single string — no markdown, JSON, or framing-aware
parsing is performed.

## Arguments

| Name     | Required | Description                                      |
|----------|----------|--------------------------------------------------|
| `<file>` | yes      | Path to the file to count. Use `-` to read stdin. |

Exactly one positional argument is required (`cobra.ExactArgs(1)`).

## Flags

`count` defines no flags of its own. It honours the persistent flags:

| Flag         | Type   | Default       | Description                                          |
|--------------|--------|---------------|------------------------------------------------------|
| `--encoding` | string | `o200k_base`  | Tokenizer encoding (`o200k_base` or `cl100k_base`).  |
| `--format`   | string | `text`        | Output format. `text` and `json` are honoured here; `md` is accepted globally but renders as `text` for `count`. |

The `--reference-window` persistent flag has no effect on `count`.

## Output

### `--format text` (default)

A single tab-separated line:

```text
<file>	<n> tokens	<bytes> bytes	(<encoding>)
```

Example:

```text
README.md	1284 tokens	5421 bytes	(o200k_base)
```

### `--format json`

A single JSON object on one line:

```json
{"path":"README.md","encoding":"o200k_base","tokens":1284,"bytes":5421}
```

| Field      | Type   | Description                              |
|------------|--------|------------------------------------------|
| `path`     | string | Path passed on the command line (`-` if stdin). |
| `encoding` | string | Active tokenizer encoding name.          |
| `tokens`   | int    | Token count.                             |
| `bytes`    | int    | Raw byte length of the input.            |

## Exit codes

| Code | Meaning                                                  |
|------|----------------------------------------------------------|
| 0    | Success.                                                 |
| 1    | I/O error (file not found, unreadable) or invalid flag (e.g. unknown `--encoding`, `--format`). |

## Examples

Count one file:

```bash
tokopt count .github/copilot-instructions.md
```

Count from stdin:

```bash
cat AGENTS.md | tokopt count -
```

Use a different encoding (older OpenAI / GPT-4 family):

```bash
tokopt count --encoding cl100k_base prompt.txt
```

JSON output for a script:

```bash
tokopt count --format json README.md | jq '.tokens'
```

Sort every Markdown file in the repo by token count:

```bash
for f in $(find . -name '*.md'); do tokopt count "$f"; done | sort -n -k2
```

## Notes

- The tokenizer is a local approximation. Counts are stable and useful for
  before/after diffs and relative comparisons; treat them as an estimate
  for non-OpenAI model families.
- `count` does not interpret markdown, frontmatter, or JSON structure — it
  counts the file verbatim. To exclude frontmatter or boilerplate, strip
  it before piping into `count -`.
- For per-segment cost, use [`anatomy`](anatomy.md). For repo-wide config
  cost, use [`audit`](audit.md).

## See also

- [`audit`](audit.md) — repo-wide always-on / conditional / on-demand totals.
- [`anatomy`](anatomy.md) — seven-segment decomposition of a single prompt.
- [`../concepts/token-vocabulary.md`](../concepts/token-vocabulary.md)
- [`../reference/encodings.md`](../reference/encodings.md)
