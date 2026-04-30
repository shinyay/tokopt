# Encodings

`tokopt` counts tokens with a local BPE tokenizer (via
[`tiktoken-go`](https://github.com/pkoukk/tiktoken-go)). The
**encoding** is the table that maps bytes ↔ token IDs. Different model
families use different encodings, so the *same* text produces *different*
token counts depending on which one you choose.

## What "encoding" means

Modern LLMs don't read characters or words — they read **tokens**, which
are subword fragments. An encoding defines:

1. The vocabulary (the fixed set of token IDs the model recognises).
2. The merge rules (how raw bytes are greedily combined into tokens).

Two encodings can disagree on how to chunk the same input. `cl100k_base`
might split `"github.com"` into 3 tokens; `o200k_base` might fit it in 2.
That's why count results shift when you flip the flag.

> Tokens are the honest unit for design. Pricing changes; vocabularies
> rarely do. tokopt reports tokens, not dollars, on purpose.

## Supported encodings

`tokopt` ships with two encodings — both BPE, both from OpenAI's
`tiktoken` family.

| Encoding       | Default? | Used by                                                | Notes |
|----------------|:--------:|--------------------------------------------------------|-------|
| `o200k_base`   | ✅       | GPT-4o family; current Copilot Chat models.            | ~200k vocabulary. Better at multilingual and code than `cl100k_base`. **Use this unless you have a reason not to.** |
| `cl100k_base`  |          | GPT-3.5 / GPT-4 (legacy turbo) family.                 | ~100k vocabulary. Still a reasonable proxy for many code-tuned and instruction-tuned older models. |

Anything else is rejected at startup with exit code `1`:

```text
error: unknown encoding "p50k_base" (supported: o200k_base, cl100k_base)
```

## Choosing an encoding

| Target model family                                   | Pick           |
|-------------------------------------------------------|----------------|
| GPT-4o, GPT-4o-mini, current Copilot Chat             | `o200k_base`   |
| GPT-3.5-turbo, GPT-4 (legacy 8k/32k turbo)            | `cl100k_base`  |
| You don't know yet                                    | `o200k_base`   |
| Claude / Llama / Gemini / Mistral (non-OpenAI)        | `o200k_base` — but treat counts as **directional** |

> [!IMPORTANT]
> For non-OpenAI families (Claude, Llama, Gemini, Mistral, …) tokopt's
> count is a **local approximation**, not a billing oracle. Use it for
> *relative* comparisons (before/after diffs, ranking the heavy tail,
> spotting anti-patterns) — not to predict the invoice. For exact
> billing, use the provider's own count endpoint.

## How to set it

`--encoding` is a persistent flag — every subcommand accepts it.

```bash
tokopt audit --encoding cl100k_base .
tokopt count --encoding cl100k_base README.md
tokopt report --encoding cl100k_base . --threshold 800
echo "hello world" | tokopt count --encoding cl100k_base -
```

Default (no flag): `o200k_base`.

## What changes if I switch encodings?

The same input file, counted with both encodings:

```bash
tokopt count --encoding o200k_base  README.md
# README.md  1284 tokens  5421 bytes  (o200k_base)

tokopt count --encoding cl100k_base README.md
# README.md  1397 tokens  5421 bytes  (cl100k_base)
```

In this example the count drifts ~9%. Typical drift is 5–15% on
English-heavy prose; up to 30%+ on heavily multilingual text or unusual
Unicode where `o200k_base`'s larger vocabulary is more efficient.

Three practical implications:

1. **Be consistent.** If you set a `--threshold` in CI, pin the same
   `--encoding` everywhere. Switching encodings can move a budget
   in/out of the red without any actual config change.
2. **Document your choice.** Add `--encoding` (and the tokopt version)
   to the commit/PR comment that records the budget number.
3. **Don't compare across encodings.** A 1,200-token always-on tax in
   `o200k_base` is not directly comparable to 1,200 in `cl100k_base`.

## Future encodings

Adding a new encoding is largely upstream's job: tokopt's tokenizer
package is a thin wrapper around
[`tiktoken-go`](https://github.com/pkoukk/tiktoken-go). When upstream
ships a new encoding (and a model family worth supporting starts using
it), it can be added to the allow-list with a one-line change.

If you need an encoding that isn't supported, open an issue against
this repo and link the upstream `tiktoken-go` PR / release that adds it.

## See also

- [`cli-reference.md`](cli-reference.md) — full flag table.
- [`output-formats.md`](output-formats.md) — what `encoding` looks like
  in JSON output (every payload includes the encoding it was counted with).
- [`../concepts/token-vocabulary.md`](../concepts/token-vocabulary.md)
  — why tokopt reports tokens, not dollars.
