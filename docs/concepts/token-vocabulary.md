# Token vocabulary

A short primer on the words tokopt and the LLM ecosystem use. Half
glossary, half short essay. If a sibling doc uses a term you don't
recognise, it should be defined here.

---

## Token

The unit of LLM accounting. Not a character, not a word — a **subword
piece** chosen by the tokenizer.

A token can be a whole word (`" the"`), a fragment (`"ization"`), a
single character, or even a single byte. Whitespace usually attaches
to the following token. Numbers, code, and non-English text tokenize
differently from English prose, and almost always less efficiently.

The only true way to know how many tokens a string costs is to run it
through the tokenizer. tokopt does this for you.

---

## Tokenizer

The algorithm that turns text into tokens. Modern tokenizers are
**byte-pair encoding** (BPE) or **SentencePiece** variants — they learn
a fixed vocabulary by greedily merging the most common adjacent pairs
in a training corpus, then split new text using that vocabulary.

tokopt uses [`tiktoken`](https://github.com/openai/tiktoken), OpenAI's
BPE tokenizer, as its counting engine. It's a vendor-neutral
approximation: the number won't be byte-perfect for non-OpenAI model
families, but the **deltas** — the only thing optimisation actually
cares about — are honest and reproducible.

---

## Encoding

The specific token table a tokenizer uses. Two encodings tokopt
exposes:

- **`o200k_base`** — OpenAI's GPT-4o family encoding. tokopt's default.
- **`cl100k_base`** — the older GPT-3.5 / GPT-4 family encoding.

Pick whichever is closer to your target model. Switch with the global
flag:

```text
tokopt audit . --encoding cl100k_base
```

Most files differ by only a few percent between the two encodings.
Pick one and stick with it for any before/after comparison; mixing
encodings invalidates deltas.

---

## Context window

The number of tokens a model can "see" at once during a single forward
pass. Different model families have different windows: a few thousand
at the small end, a few hundred thousand at the large end, with a
million-token tier on top.

The window is a **shared budget**. Conceptually:

```text
total = system + always-on + tools + history + retrieved + user + reasoning
```

Every segment competes with every other for the same budget, and the
**output** the model is about to write also lives in the same window.
Fill the window with input and there is no room left for an answer.

---

## The 7 canonical segments

The mental model `tokopt anatomy` measures against. Every LLM call is
built from these seven, and tokopt accepts each as a separate `--<name>`
flag (or as a key in the `--json` input):

| Segment       | One-line definition                                                            |
| ------------- | ------------------------------------------------------------------------------ |
| `system`      | The model's role and guardrails. Set by the host, often invisible to the user. |
| `always-on`   | Project-level instructions sent on every turn (the tax).                       |
| `tools`       | The catalog of tools / functions the model can call (names, params, descs).    |
| `history`     | Prior turns of the conversation, replayed each call.                           |
| `retrieved`   | Snippets pulled from RAG / search / files and pasted in for grounding.         |
| `user`        | The new user message — the only segment the user typed this turn.              |
| `reasoning`   | Optional scaffold for chain-of-thought / scratch tokens.                       |

See [three-layer-model.md](three-layer-model.md) for how `always-on`,
plus the *conditional* and *on-demand* layers, map onto these.

---

## Always-on / conditional / on-demand

The three buckets `tokopt audit` classifies static config into, based
on **when the bytes get sent to the model**:

- **always-on** — sent on every turn.
- **conditional** — sent only when a trigger matches (`applyTo` glob,
  agent invocation, MCP tool catalog used during an agent step).
- **on-demand** — skills loaded only when their `description:`
  semantically matches the user's prompt.

Long form: [three-layer-model.md](three-layer-model.md).

---

## Tax / budget / threshold

Closely related but distinct:

- **Tax** — the always-on per-turn token cost. A measurement.
- **Budget** — the cap you intend the tax to stay under. A decision.
- **Threshold** — the value passed to `tokopt report --threshold N`
  that turns the budget into an enforceable CI gate. A mechanism.

A repo without a budget has a tax it doesn't know about. A repo with a
budget but no threshold has a budget nobody enforces. A threshold
without a budget is just a number someone made up.

---

## Heavy tail

The long tail of high-cost outliers in real usage logs. In practice,
LLM token spend is sharply Pareto-ish: a small fraction of calls account
for a disproportionate share of tokens — long chains of tool calls, runaway
retrieval, an agent that fell into a loop, a single 50,000-token paste.

`tokopt tail --input <log>` reports `p50 / p90 / p95 / p99 / max` and
surfaces the top-N outlier records. The point is not the median — it's
the shape of the right edge. A p99/p50 ratio of 100× is normal; a p99/p50
ratio of 5× means either you've already optimised the tail or your log
is too short to have caught one yet.

---

## Reference window

An opt-in flag that lets you express the always-on tax as a **percentage
of an arbitrary context window**:

```text
tokopt audit . --reference-window 200000
```

…will add a "(0.9% of 200000-token reference window)" annotation to the
tax line. Useful when budgeting against a specific target model
(200k-context, 1M-context, etc.) without baking that assumption into
the tool itself. The default is **off** — tokopt reports raw tokens
unless you opt in, because there is no honest universal default for
"the" window size.

---

## Anti-pattern

A configuration shape that reliably produces silent token waste.
tokopt's `detect` command catches several known ones — over-large
always-on files, skills with vague descriptions that never trigger,
duplicated guidance across `AGENTS.md` and `copilot-instructions.md`,
and a handful of others. Each finding has a `severity` and a
`confidence` (`measured` or `heuristic`); the report ranks
recommendations by **estimated tokens saved**.

The point of an anti-pattern catalog is not to find every bad smell.
It's to find the smells that cost real tokens, sorted by how many.

---

## What to read next

- [three-layer-model.md](three-layer-model.md) — the central mental model.
- [always-on-tax.md](always-on-tax.md) — the most important number
  tokopt produces.
- [../reference/encodings.md](../reference/encodings.md) — full notes
  on `o200k_base` vs `cl100k_base`.
- Source repo —
  [Chapter 2: What is a token](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/02-what-is-a-token.md)
  and
  [Chapter 3: Tokenization algorithms](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/03-tokenization-algorithms.md).
