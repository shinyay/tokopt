# Quickstart — your first 5 minutes with tokopt

Three commands, one tutorial. By the end of this page you will have:

1. Audited a real repository for its always-on token cost.
2. Decomposed a single LLM context window into named segments.
3. Run the anti-pattern detector and read the suggestions.

Each step explains what you're seeing, not just what to type.

---

## Before you start

Verify `tokopt` is installed and on your `PATH`:

```bash
tokopt --version
```

If that fails, follow [`installation.md`](installation.md) first — it
takes about 90 seconds.

> Throughout this page, output blocks are illustrative — the exact
> token counts and file paths will differ for your repo. The shape of
> the output (column names, layer labels) is what to match against.

---

## Step 1 — Audit a real repository

`tokopt audit` walks a directory looking for files that LLMs and
agents will load (Copilot instructions, prompts, agent definitions,
skills, MCP configs). It tokenises each, and groups them by **when
the tokens are paid**:

- **always-on** — burned on every single LLM call into this repo.
- **conditional** — paid only when something triggers them (an
  `applyTo:` glob matches, an agent step fires, an agent is invoked).
- **on-demand** — skills and references that load only when matched
  by intent.

Pick any repo on disk and `cd` into it. If you don't have one handy,
clone the companion guide repo:

```bash
git clone https://github.com/shinyay/getting-started-with-token-optimization
cd getting-started-with-token-optimization
```

Then run:

```bash
tokopt audit .
```

You'll get something like:

```text
tokopt audit  root=.  encoding=o200k_base
always-on tax: 2532 tokens
conditional:   11414 tokens (paid only when triggered: applyTo, agent step, agent invoked)
on-demand:     38397 tokens (skills loaded only when matched)

TOKENS  BYTES   SCOPE        CATEGORY      PATH                                NOTE
1284    5120    always-on    instructions  .github/copilot-instructions.md
 612    2456    always-on    instructions  AGENTS.md
 636    2540    always-on    instructions  .github/instructions/style.md       applyTo:**
 503    2010    on-demand    skill         skills/heavy-tail/SKILL.md
 464    1856    conditional  agent         agents/token-doctor.agent.md
...
```

What each column means:

- **TOKENS** — token count under the configured tokenizer
  (default `o200k_base`, the GPT-4o family encoding).
- **BYTES** — file size on disk; useful to spot files that are
  byte-cheap but token-expensive (lots of code) or vice-versa.
- **SCOPE** — `always-on` / `conditional` / `on-demand`. This is
  the main lens — it tells you what the token cost actually pays
  for.
- **CATEGORY** — what kind of file (instructions, skill, agent,
  prompt, ...). Useful when an entire category is too heavy.
- **PATH** — the file, relative to the audit root.
- **NOTE** — extra context, e.g. the `applyTo:` glob that makes a
  conditional file conditional.

The headline number is **always-on tax**. That's what every Copilot
turn pays before your user message even gets sent. For why these
three layers matter and how to think about budgeting them, see
[`concepts/three-layer-model.md`](concepts/three-layer-model.md).

---

## Step 2 — Anatomise a single context window

`tokopt audit` answers "how heavy is my repo's static config?".
`tokopt anatomy` answers a different question: "given a single LLM
call, how is its input token budget being spent across the canonical
segments?"

The seven segments tokopt knows about: `system`, `always-on`,
`tools`, `history`, `retrieved`, `user`, `reasoning`. Every flag is
optional — only the segments you pass are counted. The rest are
treated as zero.

This repo ships realistic demo files in
[`examples/`](https://github.com/shinyay/tokopt/tree/main/examples)
that you can use as inputs. Clone the tokopt repo (one-time):

```bash
git clone https://github.com/shinyay/tokopt
cd tokopt
```

Then decompose a hypothetical context window built from one always-on
instruction file plus one user message:

```bash
tokopt anatomy \
  --always-on examples/always-on.txt \
  --user      examples/user-message.txt
```

You'll see:

```text
tokopt anatomy  encoding=o200k_base  total input=481 tokens

SEGMENT    TOKENS  BYTES  % OF INPUT
always-on  407     1612   84.6%
user       74      327    15.4%
```

Read this as: "this hypothetical call is 481 input tokens, of which
~85% is always-on instructions and ~15% is the user's actual
question." That ratio is the lever — every additional always-on
token comes out of your effective ceiling for `history`, `retrieved`,
and `tools` on every future turn.

Segment names in one line each:

- **system** — the model's system prompt (provider-set or
  application-set).
- **always-on** — your custom instructions / `AGENTS.md` /
  `copilot-instructions.md`. Sent every turn.
- **tools** — JSON schemas and descriptions for callable tools /
  functions.
- **history** — prior turns in this conversation.
- **retrieved** — RAG hits, file attachments, web fetches.
- **user** — the current user message.
- **reasoning** — scratchpad / chain-of-thought scaffolding (when
  applicable).

You can pass multiple flags at once to model a richer call, or pass
a single JSON file via `--json` if you have a captured trace.

---

## Step 3 — Detect anti-patterns

`tokopt audit` tells you the cost. `tokopt detect` tells you what,
specifically, looks suspicious — and how to fix it.

```bash
tokopt detect .
```

Sample output:

```text
tokopt detect  2 finding(s)

[INFO] AGENTS.md is large and is sent on every agent step (huge-agents-md, measured)
  location: AGENTS.md
  evidence: 1416 tokens × every agent step
  fix:      Trim to landmines and conventions only; push how-tos into on-demand docs (Ch 12 P1, P5).
  saves:    up to ~916 tokens (measured: file tokens (1416) − 500-token target)
  ref:      Ch 14 #1

[WARN] Always-on instruction file is large (kitchen-sink-system-prompt, measured)
  location: .github/copilot-instructions.md
  evidence: 1116 tokens — sent on every interaction
  fix:      Cut to the smallest set of rules that change behaviour. Push details into on-demand skills (Ch 12 P1).
  saves:    up to ~616 tokens (measured: file tokens (1116) − 500-token target)
  ref:      Ch 14 #1
```

Each finding has:

- a stable **id** (e.g. `huge-agents-md`) you can grep / suppress
- a **confidence** marker — `measured` (token-counted) or `heuristic` (rule-of-thumb)
- a **location**, **evidence**, suggested **fix**, and the maximum
  **saves** that fix would yield
- a **ref** pointer back to the published guide chapter for the deeper
  rationale

The full detector catalog (10 finding IDs across 9 detector functions)
lives in [commands/detect.md](commands/detect.md).

Severity levels (`info` / `warn` / `high` / `critical`):

- **`high`** / **`critical`** — measurable always-on tax or a behavioural bug
  (e.g. a skill that won't load).
- **`warn`** — a meaningful inefficiency or mild risk.
- **`info`** — a stylistic / hygiene nit.

> `tokopt detect` is **read-only**. It will never edit, rename, or
> reformat a file. Every finding is a suggestion you apply by hand
> (or by asking your agent to apply).

---

## Step 4 — Gate it in CI (preview)

`tokopt report` is `audit` + `detect` in one report, plus a
`--threshold` flag that exits non-zero if your **always-on tax**
exceeds a budget. That's the hook for CI:

```yaml
# .github/workflows/token-budget.yml (excerpt)
- name: Install tokopt
  run: curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
- name: Enforce always-on token budget
  run: tokopt report . --threshold 800
```

If the always-on total is over 800 tokens, the step exits with code
2 and the PR check fails. The number is yours to set — start
generous, ratchet down.

For the full workflow (caching, matrix, PR comment integration),
see [`integrations/github-actions.md`](integrations/github-actions.md).

---

## What you just did

| Command          | Question it answers                                                    |
| ---------------- | ---------------------------------------------------------------------- |
| `tokopt audit .` | "How much do my LLM configs cost, and where is the cost concentrated?" |
| `tokopt anatomy` | "For one specific call, how is the input budget distributed?"          |
| `tokopt detect .`| "What in my config looks like a known anti-pattern, and how do I fix it?"|

These three are the daily-driver loop: audit to see the bill,
anatomy to understand a specific call, detect to get a worklist.

---

## Where to go next

- 🧠 Understand the layer model — read
  [`concepts/three-layer-model.md`](concepts/three-layer-model.md).
- 📖 Look up every flag — start with
  [`commands/audit.md`](commands/audit.md), then
  [`commands/anatomy.md`](commands/anatomy.md),
  [`commands/detect.md`](commands/detect.md),
  [`commands/report.md`](commands/report.md),
  [`commands/tail.md`](commands/tail.md),
  [`commands/count.md`](commands/count.md).
- 🔬 Walk a real repo from audit to fix in
  [`use-cases/auditing-a-template-repo.md`](use-cases/auditing-a-template-repo.md).
- ⌨️ Wire one-keypress audits into the editor with
  [`integrations/vscode-tasks.md`](integrations/vscode-tasks.md).
- 💬 Reach `tokopt` from inside Copilot Chat with
  [`integrations/copilot-skills-and-agent.md`](integrations/copilot-skills-and-agent.md).
- 🚦 Gate PRs with the full workflow in
  [`integrations/github-actions.md`](integrations/github-actions.md).
