# The always-on tax

The single most important number tokopt produces. If you only ever look
at one line of `tokopt` output, look at this one.

---

## What it is

The **always-on tax** is the total token count of every file that gets
prepended to *every single LLM call* in a project. Concretely, in a
Copilot repo, it's the sum of:

- `.github/copilot-instructions.md`
- root `AGENTS.md` (and `.github/AGENTS.md` if present)
- anything else loaded unconditionally by the host

It is **not** the size of your `skills/` directory. It is **not** the
size of your `agents/` directory. Those have triggers; the always-on
layer doesn't. See [three-layer-model.md](three-layer-model.md) for the
distinction.

---

## Why "tax"

It's an economic framing, and it's deliberate.

A tax is a fixed cost paid on every transaction, whether or not the
transaction needed it. Your always-on configuration behaves the same
way: every chat turn — useful, useless, exploratory, automated — pays
the same flat number of tokens before any actual work begins.

It's the SaaS subscription baseline you pay even in months when nobody
opened the product. The number isn't huge per call. It's huge per
*month* of calls.

---

## Why it grows silently

Three forces, all of them sociologically obvious in hindsight:

1. **"Just one more line."** Every PR that touches behaviour adds a
   defensive sentence to `copilot-instructions.md` to prevent a
   recurrence. Nobody ever removes lines. Five-line file becomes a
   fifty-line file becomes a five-hundred-line file.
2. **Kitchen-sink templates.** Someone copies a "great copilot-instructions
   from the internet" with sections for code style, commit messages,
   security, accessibility, testing, deployment, and a personal note
   from the author about tabs vs spaces. None of it is wrong. Most of
   it is on every turn for no reason.
3. **Onboarding accumulation.** Every new contributor adds their own
   preferences "to be safe" — preferred phrasings, library bans,
   project glossary terms. Each addition is reasonable in isolation;
   the sum is a tax everyone pays forever.

The growth pattern is monotonic and invisible. Nobody runs `wc -c
copilot-instructions.md` after a PR. That's the gap tokopt fills.

---

## What's a healthy budget

Honest answer: it depends on context-window size and turn count. There
is no universal number. As a rough heuristic for a typical Copilot
repo:

| Always-on tax     | Verdict                                              |
| ----------------- | ---------------------------------------------------- |
| < 500 tokens      | Lean. Probably nothing to triage.                    |
| 500–1,000 tokens  | Comfortable. Worth a re-read once a quarter.         |
| 1,000–2,000 tokens| Starting to crowd. Do a focused triage pass.         |
| 2,000+ tokens     | Time to triage. Most repos this large have ≥30%      |
|                   | content that belongs in conditional or on-demand.    |

Treat these as guidelines, not laws. A 3,000-token tax can be perfectly
fine in a project that makes ten chat calls a week; it's painful in one
that runs an automation loop hitting Copilot every minute. **The tax is
a multiplier on turn count, and turn count is a property of how the
project gets used, not how big the file is.**

---

## Math: what does a tax cost over time?

Same file, three usage profiles:

```text
tax = 2,000 tokens

solo developer:    2,000 × 20 turns/day  × 20 days/mo =   800,000 tokens/mo
small team:        2,000 × 50 turns/day  × 30 days/mo = 3,000,000 tokens/mo
agentic loop:      2,000 × 500 turns/day × 30 days/mo = 30,000,000 tokens/mo
```

Same 2 kB file. Three orders of magnitude in cost. Cutting that file
in half does the same work as throttling the loop, and is much easier.

This is also the answer to "should I care about 200 tokens?". In the
solo case, no. In the agentic-loop case, 200 tokens × 500 × 30 = 3M
tokens/month. Yes, you should care about 200 tokens.

---

## How to find your tax

```text
tokopt audit .
```

The first line of the report is:

```text
always-on tax: 1842 tokens
```

That's the number. (If you passed `--reference-window 200000`, it's
also expressed as a percentage of that window.)

For a richer view that includes anti-pattern findings and ranked
recommendations:

```text
tokopt report .
```

Same first line, plus the things that pushed it up.

---

## How to reduce it

Triage rules, in roughly the order they pay off:

- **Move kitchen-sink sections to skills.** Anything starting with
  "When the user asks about X, do Y" is a skill, not always-on guidance.
  Loading it on demand drops it from "every turn" to "the turns it
  actually applies to". See `skills/<name>/SKILL.md`.
- **Move file-specific advice to `applyTo` instruction files.** If a
  rule only matters when editing `*.go` or `tests/**`, put it in
  `.github/instructions/<name>.instructions.md` with the right `applyTo`
  glob. Conditional, not always-on.
- **Move PR formatting to `.github/PULL_REQUEST_TEMPLATE.md`.** It's
  not LLM context at all; it's GitHub UI. Don't pay tokens for it.
- **Delete defensive sentences that haven't fired.** "Don't make up
  function names" is in every modern model's training. You don't need
  to re-instruct it on every turn.

After each pass, re-run `tokopt audit .` and check the delta. The
loop is: measure → cut one thing → re-measure.

---

## What about CI?

To keep a healthy tax healthy, gate it on PRs:

```text
tokopt report . --threshold 1500
```

Exits with code 2 if the always-on tax exceeds 1,500 tokens. Wire that
into a required check and the PR that adds 800 tokens of guidance has
to justify itself in review. The threshold gates **only the always-on
total** — conditional and on-demand are intentionally not budgeted by
this flag, because their per-turn cost is contingent, not fixed.

See [../use-cases/ci-budget-gating.md](../use-cases/ci-budget-gating.md)
for a full GitHub Actions recipe.

---

## What to read next

- [three-layer-model.md](three-layer-model.md) — why "always-on" is
  one of three layers and what the other two cost.
- [../commands/audit.md](../commands/audit.md) — full reference for
  `tokopt audit`.
- [../commands/report.md](../commands/report.md) — full reference for
  `tokopt report`, including the `--threshold` gate.
- Source repo —
  [Chapter 7: The economics of tokens](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/07-the-economics-of-tokens.md)
  and
  [Chapter 14: Anti-patterns and pitfalls](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/14-anti-patterns-and-pitfalls.md).
