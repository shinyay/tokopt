# What is tokopt?

A one-page elevator. Read this before installing if you want to know
what you're about to put on your `PATH`.

---

## What it is

**tokopt is a small Go CLI that measures the token cost of the
LLM-facing files in your repository** — system prompts, agent
definitions, skills, conditional instructions, `AGENTS.md`,
`copilot-instructions.md`, the lot — and surfaces the anti-patterns
that quietly inflate them. It runs locally, it reads files on disk,
it prints token counts. That is the whole job.

It deliberately reports tokens, not dollars. Pricing changes month
to month; the underlying unit of account does not. If your
always-on tax is 4,200 tokens today, it will still be 4,200 tokens
when the next price sheet drops.

---

## What it does

Six commands. Verified against
[`tools/tokopt/cmd/tokopt/main.go`](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/tools/tokopt/cmd/tokopt/main.go)
in the source repo.

- **`audit [path]`** — scans a repo's always-on Copilot
  configuration and reports the token tax (the cost paid on
  *every* call).
- **`anatomy`** — decomposes a prompt into the seven canonical
  segments (`system`, `always-on`, `tools`, `history`, `retrieved`,
  `user`, `reasoning`) and tells you where the tokens went.
- **`detect [path]`** — runs anti-pattern detectors against the
  static config and flags suspected token waste.
- **`tail`** — heavy-tail percentile analysis (p50/p90/p95/p99/max
  + top-N outliers) over a usage log, JSONL or CSV.
- **`report [path]`** — combined audit + detect dashboard with
  ranked recommendations; with `--threshold N`, exits code 2 if
  the always-on tax exceeds `N` (the CI gate).
- **`count <file>`** — count tokens in a single file (or stdin
  with `-`). The simplest possible smoke test.

Three global flags worth knowing: `--encoding` (`o200k_base` by
default, `cl100k_base` available), `--format` (`text`, `json`, or
`md`), and `--reference-window` (express the always-on tax as a
percentage of a context window of your choice — opt-in).

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
- **Not a magic optimiser.** It does not rewrite your prompts. It
  gives you measured numbers and ranked findings; you decide what
  to change. Optimisation is a human decision; measurement is the
  bedrock you make it on.
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

```
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

tokopt is the **measurement layer**. The *guide* (sixteen chapters
of conceptual background), the *skills* (five short Copilot Chat
skills that wrap the CLI), and the *agent* (`@token-doctor`, which
orchestrates them) live in the source repo:
<https://github.com/shinyay/getting-started-with-token-optimization>.

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
