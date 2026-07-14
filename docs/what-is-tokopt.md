# What is tokopt?

A one-page elevator. Read this before installing if you want to know
what you're about to put on your `PATH`.

---

## What it is

**tokopt is a local Go CLI for measuring and safely reducing the token cost
of LLM-facing repository assets and transcripts.** It scans system prompts,
agent definitions, skills, scoped instructions, `AGENTS.md`, and
`copilot-instructions.md`; it can also preview deterministic slim operations,
manage recovery artifacts, and compact JSONL chat history. No LLM or telemetry
is involved.

Tokens remain the primary measurement. Optional nano-AIU output is an
input-only comparison scenario, not a dollar amount or invoice estimate.

---

## What it does

Thirteen root commands. Verified against
[`tools/tokopt/cmd/tokopt/main.go`](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/tools/tokopt/cmd/tokopt/main.go)
in the source repo.

- Measurement and diagnosis: **`audit`**, **`anatomy`**, **`count`**,
  **`detect`**, **`tail`**, and **`report`**.
- Deterministic transformation and recovery: **`slim`**, **`rewind`**, and
  **`chat-compact`**.
- Discovery and shell integration: **`models`**, **`version`**,
  **`completion`**, and **`help`**.

Three global flags worth knowing: `--encoding` (`o200k_base` by
default, `cl100k_base` available), `--format` (`text`, `json`, or
`md`), and `--reference-window` (express the always-on tax as a
percentage of a context window of your choice — opt-in). `--credit-model`
adds the input-only nano-AIU scenario.

See [reference/cli-reference.md](reference/cli-reference.md) for the full reference.

---

## What it is NOT

Setting expectations matters at least as much as listing features.

- **Not a Copilot, Claude, or GPT API wrapper.** tokopt does not
  call any LLM. It does not need a key. It does not phone home. It
  reads files; it counts tokens; it exits.
- **Not a runtime token-meter.** It measures the *static* cost of
  files that get sent to LLMs. If you want to instrument live
  traffic, that's a different tool — and the output of that tool
  is what you'd feed to `tokopt tail` for percentile analysis.
- **Not an autonomous rewriter.** `slim` is dry-run by default.
  Mutation requires explicit `--apply`, clean-tree/atomic-write checks, and
  a second `--allow-format-change` intent before JSON/YAML can change media
  type (normally to TOON).
  You decide what to change.
- **Not coupled to any single vendor.** tokopt uses
  [`tiktoken`][tt] (`o200k_base` by default) as a vendor-neutral
  approximation. The number won't be byte-perfect for non-OpenAI
  model families, but it's stable, it's reproducible, and the
  *deltas* — the only thing optimisation actually cares about —
  are honest.

[tt]: https://github.com/openai/tiktoken

---

## Who it's for

- **Developers building Copilot custom agents and chat skills.**
  You want to know whether the skill you just wrote is going to
  load on every prompt and how big it is when it does.
- **Platform / DevEx teams setting per-PR token budgets in CI.**
  `tokopt report --threshold` is the gate; the rest of the docs
  tell you where to put it.
- **Anyone curious about where their LLM context window is
  actually being spent.** Run `audit`, then `anatomy` on a typical
  call. The first run is usually surprising.

---

## The 3-layer mental model

tokopt thinks about LLM context costs in three layers. This is the
single most important idea in the tool, so it gets its own page —
[concepts/three-layer-model.md](concepts/three-layer-model.md) — but
here's the elevator version:

```text
   ┌──────────────────────────────────────────────────────┐
   │  Layer 3 — On-demand     (loaded only when invoked)  │
   │     skills, retrieval                                │
   ├──────────────────────────────────────────────────────┤
   │  Layer 2 — Conditional   (loaded when X matches)     │
   │     agents, scoped instruction files, MCP catalogs   │
   ├──────────────────────────────────────────────────────┤
   │  Layer 1 — Always-on     (loaded on EVERY call)      │
   │     system prompt, AGENTS.md, copilot-instructions   │
   └──────────────────────────────────────────────────────┘
```

The bottom layer is the one you pay for first, on every prompt,
forever. tokopt reports it as the **always-on tax** because that's
what it is. The middle and top layers are bigger but cheaper
*per call* — they only show up when something triggers them. Most
of the wins from `audit` and `detect` come from spotting things
that ended up in Layer 1 by accident.

---

## How it fits a Copilot toolchain

tokopt is the local **measurement and deterministic transformation layer**.
The *guide* (sixteen chapters of conceptual background), the canonical
Copilot CLI plugin (**10 skills + 2 agents**), and the VS Code companion live
across the source and sibling repositories:

- Guide + Go source: <https://github.com/shinyay/getting-started-with-token-optimization>
- Copilot CLI plugin: <https://github.com/shinyay/tokopt-skills>
- VS Code companion: <https://github.com/shinyay/tokopt-vscode>

If you only want the binary and the docs that ship with it, you're
in the right place. If you want the conceptual material or the
Copilot-side skills, follow the link.

---

## What's next

- New here? [quickstart.md](quickstart.md) — install and run your
  first audit.
- Want the backstory? [motivation.md](motivation.md) — why this
  exists at all.
- Ready for detail? [reference/cli-reference.md](reference/cli-reference.md) — the
  full reference.
