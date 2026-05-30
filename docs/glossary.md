# Glossary

Terminology used across tokopt's documentation. Each entry is a short
definition plus a cross-link to the document where the concept is treated
in depth. Alphabetical.

---

## Always-on tax

The tokens spent on **every** LLM call before the user's message even
begins — system prompt, always-on instructions, tool catalogs. tokopt
measures the always-on tax with [`audit`](commands/audit.md) and gates
on it with [`report --threshold`](commands/report.md). Full treatment in
[concepts/always-on-tax.md](concepts/always-on-tax.md).

## Anatomy

In tokopt's sense, the **seven-segment breakdown** of a single LLM call's
input: `system`, `always-on`, `tools`, `history`, `retrieved`, `user`,
`reasoning`. [`tokopt anatomy`](commands/anatomy.md) reports tokens, bytes,
and `% of input` for each segment, so you can see where the budget went.

## Anti-pattern

A measured **token-cost smell** with a stable ID, a severity, and (when
measurable) an `est_tokens_saved` figure. tokopt ships
[10 detectors](commands/detect.md#detectors) — `kitchen-sink-system-prompt`,
`mcp-overload`, `reasoning-leakage`, etc. Anti-patterns are surfaced by
[`tokopt detect`](commands/detect.md), never auto-fixed.

## Budget

A numeric ceiling on the always-on token cost, enforced by
[`tokopt report --threshold N`](commands/report.md). When
`always_on_total > N`, `report` exits `2`. Budget gating in CI is
documented in
[use-cases/ci-budget-gating.md](use-cases/ci-budget-gating.md).

## `cl100k_base`

The **legacy OpenAI tokenizer encoding** used by GPT-3.5 and GPT-4
(turbo) families. ~100k vocabulary. Available in tokopt as
`--encoding cl100k_base`. Use it when targeting those older model
families. Detail in [reference/encodings.md](reference/encodings.md).

## Conditional context

**Layer 2** of the three-layer model: instructions or files loaded *only
when criteria match* — a glob, a language, a frontmatter `applyTo` rule.
Conditional context is cheaper than always-on because it isn't paid for
on every call. See
[concepts/three-layer-model.md](concepts/three-layer-model.md).

## Confidence (measured vs heuristic)

A label on every [detector finding](commands/detect.md). `measured`
means the saving estimate comes from a real token count.
`heuristic` means the finding is a behavioural / pattern match —
`est_tokens_saved` is reported as `0` because the impact is real but not
directly tokenizable.

## Context window

The **total input budget** (in tokens) a model accepts per call —
e.g. 128k or 200k. tokopt's `--reference-window` flag lets you express
the always-on tax as a percentage of this number. Conceptual background
in [concepts/token-vocabulary.md](concepts/token-vocabulary.md).

## Detector

A Go function inside tokopt that walks repository files and emits a
[finding](#finding) when a specific anti-pattern matches. The full
detector list and trigger conditions are in
[commands/detect.md#detectors](commands/detect.md#detectors).

## Encoding

A tokenizer's **vocabulary table** — the mapping from byte sequences to
token IDs. tokopt ships two: `o200k_base` (default) and `cl100k_base`.
Switching encodings changes counts because each table chunks bytes
differently. Full reference: [reference/encodings.md](reference/encodings.md).

## Finding

The structured output of a [detector](#detector): `id`, `title`,
`severity`, `confidence`, `location`, `evidence`, `recommendation`, and
`est_tokens_saved`. Findings are sorted by `est_tokens_saved`
descending in `tokopt detect` output. See
[commands/detect.md](commands/detect.md).

## Heavy tail

The pattern where a small percentage of records dominate total token
spend — a high `top_share_pct` in [`tokopt tail`](commands/tail.md)
output, typically driven by a handful of very long prompts or very
verbose tool responses. The heavy tail is where the savings live.

## History (anatomy segment)

The `history` segment in [`tokopt anatomy`](commands/anatomy.md): the
**prior chat turns** sent back to the model on each new turn. Often
the largest segment in long sessions, and the one most likely to grow
without anyone noticing.

## JSONL

JSON Lines — **one JSON object per line**, no enclosing array. The
native input format for [`tokopt tail`](commands/tail.md) when reading
from a file with `.jsonl` / `.ndjson` extension or from stdin (`--input -`).

## Layer 1 / Layer 2 / Layer 3

The three layers of the [three-layer model](#three-layer-model):

- **Layer 1 — always-on:** loaded on every call (paid for every time).
- **Layer 2 — conditional:** loaded when criteria match (cheaper).
- **Layer 3 — on-demand:** loaded only when explicitly invoked
  (cheapest per call, scales with usage).

Detail in [concepts/three-layer-model.md](concepts/three-layer-model.md).

## MCP (Model Context Protocol)

Anthropic's **tool-server protocol** — the way agent hosts discover and
invoke external tools. tokopt detects MCP overload (too many servers,
too many tools, oversize tool descriptions) via the
[`mcp-overload`](commands/detect.md#detectors) and
[`verbose-tool-descriptions`](commands/detect.md#detectors) detectors.

## `o200k_base`

The **current OpenAI tokenizer encoding** — used by the GPT-4o family
and current Copilot Chat models. ~200k vocabulary. **Default in
tokopt.** Use it unless you have a specific reason not to. See
[reference/encodings.md](reference/encodings.md).

## On-demand context

**Layer 3** of the three-layer model: loaded only when *explicitly
invoked* — a Copilot skill, an agent call, a retrieval query. Cheapest
per-call class because it isn't paid for unless used. See
[concepts/three-layer-model.md](concepts/three-layer-model.md).

## p50 / p95 / p99

**Percentiles** in [`tokopt tail`](commands/tail.md) output. `p50` is
the median (half of records are below it); `p95` is the value below
which 95% of records sit; `p99` is the 1-in-100 record. The gap between
`p50` and `p99` is a quick read on heavy-tail-ness.

## Persistent flag

A flag that **applies to every subcommand** rather than a specific one.
tokopt's persistent flags are `--encoding`, `--format`,
`--reference-window`, and `--version`. See
[reference/cli-reference.md](reference/cli-reference.md).

## Reasoning (anatomy segment)

The `reasoning` segment in [`tokopt anatomy`](commands/anatomy.md):
**model-generated reasoning trace** — Claude's extended thinking,
OpenAI's o-series reasoning tokens. Billed at output rates and usually
invisible until you measure it.

## Reference window

The **model context budget** used to compute `% of window` values in
`audit` output. Set with `--reference-window N` (default `0` = don't
report a percentage). Common values are `128000` and `200000`. Detail
on [`audit --reference-window`](commands/audit.md). Display-only —
tokopt never bakes in a window assumption.

## Retrieved (anatomy segment)

The `retrieved` segment in [`tokopt anatomy`](commands/anatomy.md):
**RAG context, search results, code snippets** pulled in by tools or
file-read requests. The segment most likely to balloon when a "small
context boost" feature gets enabled.

## Severity

A label on every detector finding: **`info` / `warn` / `high` /
`critical`** (four levels). Some detectors scale severity with
measured token counts; others are fixed. Severities never affect
`detect`'s exit code (always `0`) — gating is the job of
[`report --threshold`](commands/report.md). See
[commands/detect.md](commands/detect.md).

## Skill (Copilot)

A **chat-surface capability** defined by a `SKILL.md` file with a
description that Copilot Chat matches against the user's prompt. tokopt
ships chat skills that wrap the CLI — see
[integrations/copilot-skills-and-agent.md](integrations/copilot-skills-and-agent.md).
Loose skill descriptions are themselves an anti-pattern (they cause
unintended loads).

## System (anatomy segment)

The `system` segment in [`tokopt anatomy`](commands/anatomy.md): the
**system prompt** — model-level instructions that shape behaviour for
the whole session. Usually small in tokens but large in influence.

## Three-layer model

tokopt's **core mental model**: classify every LLM-facing file by *when*
it's loaded (always / conditional / on-demand) and budget each layer
separately. Concept doc:
[concepts/three-layer-model.md](concepts/three-layer-model.md).

## `tiktoken-go`

The **Go port of OpenAI's `tiktoken`** BPE tokenizer
([github.com/pkoukk/tiktoken-go](https://github.com/pkoukk/tiktoken-go)).
tokopt's underlying tokenizer — the reason `o200k_base` and
`cl100k_base` counts are byte-exact against OpenAI's billing.

## Token

A **subword unit** — the atomic unit a model reads, generates, and is
billed on. Not a word, not a character. Conceptual primer in
[concepts/token-vocabulary.md](concepts/token-vocabulary.md).

## Tools (anatomy segment)

The `tools` segment in [`tokopt anatomy`](commands/anatomy.md): the
**tool / function-call specifications** sent to the model. Often
under-counted because each MCP tool's `description` field is sent every
step — see the
[`verbose-tool-descriptions`](commands/detect.md#detectors) detector.

## Top share

The **percentage of total tokens** consumed by the top N records in
[`tokopt tail`](commands/tail.md) output (default `--top 5`). A high
`top_share_pct` (e.g. `>50`) means a few records are eating most of
your budget — classic heavy tail.

## User (anatomy segment)

The `user` segment in [`tokopt anatomy`](commands/anatomy.md): **your
actual message**. Should usually be more than 1% of total input — if
it isn't, the surrounding scaffolding has overgrown the actual
question, and `anatomy` will warn.

---

## See also

- [faq.md](faq.md) — common questions about these concepts.
- [reference/cli-reference.md](reference/cli-reference.md) — every flag
  for every command.
- [concepts/](concepts/) — deeper essays on the three-layer model, the
  always-on tax, and the token vocabulary.
