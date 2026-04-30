# The three-layer model

The single most important idea tokopt operationalises. Once you see
configuration through this lens, almost every "where did all my tokens
go?" question answers itself.

---

## The intuition

Every byte you put into a Copilot / agent configuration falls into
**exactly one of three buckets** — and the bucket is decided by *when
the bytes get sent to the model*, not by what they contain.

- **Always-on** — sent on **every** chat turn, no matter what the user
  asked. The system prompt, `.github/copilot-instructions.md`, root
  `AGENTS.md`. This is the tax.
- **Conditional** — sent **only when a trigger matches**. `applyTo`
  scoped instruction files (`.github/instructions/*.instructions.md`),
  agent step files (`agents/*.agent.md`), MCP tool catalogs invoked
  during an agent step. Paid only when the trigger fires.
- **On-demand** — sent **only when a description match fires**. Skills
  under `skills/<name>/SKILL.md`, loaded by Copilot when the user's
  prompt semantically matches the skill's frontmatter `description`.
  Paid only on semantic match.

```text
┌────────────────────────────────────────────────────────────┐
│  ON-DEMAND     skills/*/SKILL.md                           │   per turn:
│                loaded only on description match            │   0 unless matched
├────────────────────────────────────────────────────────────┤
│  CONDITIONAL   agents/*.agent.md, instructions/*, MCP cfg  │   per turn:
│                loaded only on applyTo / agent invocation   │   0 unless triggered
├────────────────────────────────────────────────────────────┤
│  ALWAYS-ON     copilot-instructions.md, AGENTS.md          │   per turn:
│                loaded on EVERY call                        │   100% of itself
└────────────────────────────────────────────────────────────┘
```

The bottom layer is the floor of every interaction. The other two are
overhead that *might* show up.

---

## A worked example

Imagine a repo with:

- **4 kB always-on** — one `copilot-instructions.md`, one `AGENTS.md`.
- **12 kB conditional** — five `.instructions.md` files with `applyTo`
  globs, plus one `agent.md`.
- **38 kB on-demand** — twenty-seven skills under `skills/`.

What does the model see on a given turn?

**(a) A generic chat turn.** User asks "what does this function do?".
No `applyTo` glob matches the file in focus, no agent invoked, no
skill description matches.

```text
loaded this turn: 4 kB   (just the always-on layer)
ignored:          50 kB  (12 kB conditional + 38 kB on-demand)
```

**(b) A chat turn that triggers one applyTo file.** The user is editing
`src/auth.go`; one instruction file has `applyTo: "**/*.go"` and is
3 kB.

```text
loaded this turn: 4 kB + 3 kB = 7 kB
```

**(c) A chat turn where one skill's description matches.** The user
asks "audit my Copilot config tokens"; one 2 kB skill description-matches.

```text
loaded this turn: 4 kB + 2 kB = 6 kB
```

The repo's "total config size" is **54 kB**. No turn ever loads all of
it. **"Total" is misleading — only "what's loaded right now" matters
per turn**, and that almost always means the always-on layer plus a
small handful of triggered extras.

---

## Why this matters for budgeting

Each layer has a different budgeting shape:

- **Always-on is the only number you can budget statically.** It's what
  every turn pays. If it's 4,000 tokens and you make 50 calls today,
  you've spent 200,000 tokens on the tax alone before any actual work.
- **Conditional is *contingent* cost.** You can size each file, but
  whether it shows up depends on what the user is doing. The right
  question for conditional is "is the trigger correct?", not "is this
  file too big?".
- **On-demand is *triggered* cost.** Same shape as conditional, but
  the trigger is a semantic match against the skill's `description:`
  field, not a glob or an explicit invocation. If the description is
  too vague, the skill loads when it shouldn't; too narrow and it
  never loads at all (an "orphan skill").

The practical rule: **budget the always-on layer hard, audit the other
two for correctness.**

---

## How `tokopt audit` reports it

`tokopt audit .` prints a header with all three buckets, then a table
of every file it found, classified by scope:

```text
tokopt audit  root=.  encoding=o200k_base
always-on tax: 1842 tokens
conditional:   3120 tokens (paid only when triggered: applyTo, agent step, agent invoked)
on-demand:     5471 tokens (skills loaded only when matched)

TOKENS  BYTES  SCOPE        CATEGORY               PATH                                       NOTE
1102    4881   always-on    copilot-instructions   .github/copilot-instructions.md
 740    3210   always-on    agents-md              AGENTS.md
 612    2701   conditional  scoped-instructions    .github/instructions/go.instructions.md    loaded only for matching files (applyTo glob)
 ...
1450    6420   on-demand    skill-definition       skills/token-audit/SKILL.md                skill is loaded on demand by description match
```

Read it top to bottom:

- The **`always-on tax`** line is the per-turn floor. Treat it as a
  budget number you actively defend.
- The **`conditional`** total is an *upper bound* — the worst case
  where every trigger fires at once. Real per-turn cost is almost
  always a small subset.
- The **`on-demand`** total is the same shape: cap, not actual.
- The **`SCOPE`** column on each row is the bucket assignment. The
  **`NOTE`** column tells you *why* tokopt put it there.

---

## Common mistakes

- **Treating "total token count of repo" as the cost.** Wrong. Only
  the layers loaded on a given turn count. A 50 kB skills directory
  costs zero on a turn where nothing description-matches.
- **Putting things in always-on that should be conditional.**
  "Always be helpful." Project glossary. PR template language. A 30-line
  list of preferred libraries. None of these need to be on every turn —
  they need to be on *some* turns.
- **Putting things in on-demand that the LLM never has a description-match
  path to.** A skill whose `description:` is "internal helper" will
  never trigger. It's an orphan: it costs nothing per turn, but it
  also does nothing. `tokopt detect` flags some of these.
- **Sizing optimisation effort by file size.** A 4 kB always-on file
  matters far more than a 40 kB skill. The multiplier is the number
  of turns, not the byte count.

---

## What to read next

- [always-on-tax.md](always-on-tax.md) — drill into the most
  important number tokopt produces.
- [token-vocabulary.md](token-vocabulary.md) — definitions for the
  terms used here.
- [../commands/audit.md](../commands/audit.md) — the command that
  produces the report above.
- Source repo —
  [Chapter 5: Counting tokens in practice](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/05-counting-tokens-in-practice.md)
  and
  [Chapter 6: The context window](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/06-the-context-window.md)
  for the underlying theory.
