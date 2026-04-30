# Frequently Asked Questions

A grab-bag of questions that come up in issues, chats, and review comments.
If yours isn't here, see [troubleshooting.md](troubleshooting.md) for error
symptoms or open an [issue](https://github.com/shinyay/tokopt/issues).

---

## About the project

### Q: What is tokopt?

A small Go CLI that measures the token cost of the LLM-facing files in your
repository — system prompts, agents, skills, `AGENTS.md`,
`copilot-instructions.md` — and surfaces the anti-patterns that quietly
inflate them. See [what-is-tokopt.md](what-is-tokopt.md) for the long form.

### Q: Why isn't the source code public?

For v0.1.0, tokopt ships as a binary-only release. The focus is on
**stability**, **education**, and **demonstrable measurement** rather than
on running an open-source project on day one. The companion source repo at
[shinyay/getting-started-with-token-optimization](https://github.com/shinyay/getting-started-with-token-optimization)
holds the worked examples, the integrations, and the editorial material the
tool is built to support. Opening the binary repo is on the
[roadmap](roadmap.md#long-term--open-questions) — it depends on whether
community engagement justifies the maintenance overhead of running it as a
public Go project.

### Q: Is tokopt free to use?

Yes. MIT license. See [`LICENSE`](https://github.com/shinyay/tokopt/blob/main/LICENSE).

### Q: Who built it and why?

One author, one motivation: nobody could tell you the actual token cost of a
Copilot/agent repo until you read the bill, and that opacity was producing
predictable, measurable waste. The full story is in
[motivation.md](motivation.md).

---

## Tokenization

### Q: Are tokopt's token counts the same as what OpenAI / Anthropic / Google bill me?

It depends on the model family.

- **OpenAI families using `o200k_base` or `cl100k_base`** — the count *is*
  the billing oracle. tokopt uses
  [`tiktoken-go`](https://github.com/pkoukk/tiktoken-go), the same BPE
  tables OpenAI uses to bill you.
- **Other vendors (Claude, Gemini, Llama, Mistral)** — the count is a
  **directional approximation**. Typical drift is ~5–15% on
  English-heavy content; up to 30% on heavily multilingual text. Use
  tokopt for relative comparisons (before/after, ranking the heavy tail,
  spotting anti-patterns) — not for invoice prediction. Use the vendor's
  own count endpoint for exact billing.

See [reference/encodings.md](reference/encodings.md) for the full matrix
and choosing guidance.

### Q: Why does the same file count differently with `--encoding o200k_base` vs `cl100k_base`?

Different vocabulary tables. Newer encodings (`o200k_base`, ~200k tokens)
pack more bytes per token than older ones (`cl100k_base`, ~100k tokens), so
the same input chunks differently. Typical drift on English text is 5–15%.
This is expected behaviour, not a bug. Pin your encoding in CI and
document the choice — see
[reference/encodings.md](reference/encodings.md#what-changes-if-i-switch-encodings).

### Q: My screenshot shows 47 tokens but tokopt says 51. Why?

Whitespace, line endings, and trailing newlines all count as tokens.
The most likely culprit: your screenshot truncated the trailing newline
(or the indentation, or the leading BOM) that the file actually contains.
Re-count from the raw file with `tokopt count <file>` and confirm the
byte count matches what you expect.

---

## Commands & usage

### Q: What's the difference between `audit` and `report`?

- [`audit`](commands/audit.md) is **diagnostic**: it scans your repo, prints
  the always-on tax, and always exits `0` on success. It has no
  `--threshold`. Use it to *see* the number.
- [`report`](commands/report.md) is **gating**: it does everything `audit`
  does plus a `detect` summary, and when `--threshold N` is set it exits
  `2` if `always_on_total > N`. Use it in CI.

The split is deliberate: humans run `audit` to explore; CI runs `report` to
enforce. See
[use-cases/ci-budget-gating.md](use-cases/ci-budget-gating.md) for the CI
pattern.

### Q: Why does `detect` find 5 issues but exit code 0?

Because `detect` is **informational**. It surfaces; you decide. This is
true even for `critical` findings — `detect` will never fail your build on
its own. If you want CI to fail on regressions, use
[`report --threshold N`](commands/report.md). The full exit-code contract
is in [reference/exit-codes.md](reference/exit-codes.md).

### Q: Can I scan only a specific file or directory?

Yes. Most commands take an optional `[path]` argument and default to `.`:

```bash
tokopt audit  ./packages/web
tokopt detect ./agents
tokopt report ./apps/api --threshold 1500
```

For a single file, use [`tokopt count <file>`](commands/count.md). For a
specific prompt assembly, use
[`tokopt anatomy --always-on FILE ...`](commands/anatomy.md).

### Q: How do I integrate tokopt with Copilot Chat?

Install the chat skills and the `token-doctor` agent from the source repo.
Once installed, you can ask "audit my token usage" or "show me the top
offenders" inside Copilot Chat and they call the same `tokopt` binary
under the hood. Setup is in
[integrations/copilot-skills-and-agent.md](integrations/copilot-skills-and-agent.md).

---

## Operational

### Q: Does tokopt phone home / send data anywhere?

**No.** Pure local CLI. No telemetry. No update check. No analytics. The
only network call the project ever makes is `scripts/install.sh` fetching
the release archive and its `SHA256SUMS` file from
`github.com` — and that's `install.sh`, not the binary. The binary itself
makes zero outbound requests. Confirmed by reading the code in the source
repo and by `tokopt`'s own behaviour offline.

### Q: Will tokopt work offline?

Yes, completely. The tokenizer tables are baked into the binary at build
time (statically linked via `tiktoken-go`), and every command reads files
from disk. You can run `tokopt audit .` on an air-gapped machine with no
configuration.

### Q: How big is the binary?

Roughly **2.6–3.0 MB**, statically linked, `CGO_ENABLED=0`. Single file,
no shared library dependencies. Small enough to commit into a CI cache or
ship inside a container layer without thinking about it.

### Q: Does tokopt support reading from stdin?

Partly:

- [`count`](commands/count.md) — yes. Pass `-` as the filename:
  `echo "hello" | tokopt count -`.
- [`anatomy`](commands/anatomy.md) — yes, per-segment. Pass `-` to any
  segment flag (e.g. `--always-on -`); stdin is consumed once across the
  invocation.
- [`tail`](commands/tail.md) — yes via `--input -` (treated as JSONL).
- [`audit`](commands/audit.md), [`detect`](commands/detect.md),
  [`report`](commands/report.md) — no. They walk a directory tree and
  need a path on disk.

---

## Comparisons

### Q: How is this different from `tiktoken` (Python) or `tiktoken-go`?

`tiktoken` and `tiktoken-go` are **tokenizer libraries** — they turn
strings into token arrays. tokopt **builds on top** of `tiktoken-go` to add
a diagnostic vocabulary: anatomy segments, always-on tax measurement,
anti-pattern detection, heavy-tail analysis, CI gating. Different jobs.
If all you need is `len(tokenize(s))`, you don't need tokopt.

### Q: Why not just count tokens with a Python script?

You can — and for a one-off "how big is this file" question, you should.
tokopt's value isn't `count`; it's the **diagnostic vocabulary** layered on
top: the [three-layer model](concepts/three-layer-model.md), the
[always-on tax](concepts/always-on-tax.md), the
[10 anti-pattern detector IDs](commands/detect.md#detectors), and the
CI/IDE integrations. If you find yourself reimplementing those in a
Python script, you're rebuilding tokopt.

### Q: Should I use tokopt or [some commercial tool]?

tokopt is intentionally narrow: **local CLI, no UI, no SaaS, no
telemetry**. If you need dashboards, multi-tenant rollups, alerts, or a
team-facing web app, use a commercial tool — that's not what tokopt is
for. If you want a single binary that gives you a measured number you can
gate CI on, tokopt is the right shape. The
[roadmap](roadmap.md#what-we-will-not-add) lists what tokopt will
deliberately *never* be.

---

## See also

- [troubleshooting.md](troubleshooting.md) — error symptoms with fixes.
- [glossary.md](glossary.md) — terminology dictionary.
- [reference/cli-reference.md](reference/cli-reference.md) — every flag,
  every command.
