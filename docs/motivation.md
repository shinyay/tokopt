# Motivation — why I made tokopt

This is the "why this exists" page. It's written in the first
person because the decisions behind tokopt are mine, and it would
be dishonest to launder them through the corporate plural. If you
want the *what*, read [what-is-tokopt.md](what-is-tokopt.md). If
you want the *how*, read [quickstart.md](quickstart.md). This page
is the *why*.

— Shinya Yanagihara

---

## The problem in one sentence

Copilot custom agents and skills get bigger and bigger, and nobody
can tell you what the actual token cost is until you read the bill.

That's it. That's the whole motivation. Everything else on this
page is the long form.

---

## What pushed me over the edge

I kept running into the same three shapes of problem, in my own
repos and in repos I was helping people with. None of them are
worth name-and-shaming, because every single one of them is what
you'd write the first time too — they're not mistakes, they're the
default trajectory.

- **Kitchen-sink `AGENTS.md` files.** Started as a paragraph; six
  months later it's a 200-line house style guide that gets sent on
  every single prompt, including the one where you're asking
  Copilot to rename a variable.
- **`copilot-instructions.md` that is 1k+ tokens of "always be
  helpful".** Plus a section on tone. Plus a list of preferred
  libraries. Plus a reminder to use TypeScript. All of it, every
  time, on every keystroke that triggers a completion.
- **Skills that load on the wrong description match.** A skill
  meant to fire on "explain this regex" loads when someone says
  "explain this code", because the description was written too
  loose and nobody measured.

The bill is opaque. The cause is invisible. By the time you
*notice* — by the time you go "wait, why is my context window full
before I've even started typing?" — the habits are baked in
across a dozen files and three repos. I wanted a tool that would
let me *see* the tax before I started paying it, not after.

---

## Why "measurement-driven"

You can't budget what you can't measure. Engineering teams
internalised this for SLOs. They internalised it for performance
profiling. They internalised it for code coverage and cyclomatic
complexity. Token cost is just another measured surface — a new
one, certainly, but structurally the same idea.

The "measurement-driven" framing is deliberate. It's a bet that
the LLM tooling ecosystem will mature in the same direction every
other expensive resource has matured: from anecdote, to
measurement, to budget, to gate. tokopt aims to be a small,
honest tool at the *measurement* step. The *budget* and *gate*
steps follow naturally — `report --threshold` plus a CI
integration is the gate — but they only work if the measurement
underneath is trustworthy.

That's why tokopt reports tokens, not dollars. Dollars change.
Tokens are the unit you actually design against.

---

## Why a CLI (and not a chat-only thing)

I love Copilot Chat. I use it constantly. It is the wrong place to
do measurement.

Chat is great for **explanation** — "why is this skill loading?",
"what's the always-on tax in plain English?". It is terrible for
**repeatable measurement** — you can't put a chat session in CI,
you can't diff its output between two commits, you can't run it
across thirty repos in a script. Anything that has to be the same
number twice in a row needs to live in a binary.

So tokopt aims at *both*. The CLI is the bedrock — it is the thing
that gives you the same number twice. The
[skills](https://github.com/shinyay/getting-started-with-token-optimization/tree/main/skills)
and [agent](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/agents/token-doctor.agent.md)
in the source repo are a layer on top, so that the same numbers
you can produce in CI can be produced (and explained) inside
Copilot Chat too. See [integrations/copilot-skills-and-agent.md](integrations/copilot-skills-and-agent.md)
for that bridge.

---

## The bug-catch story

This one I keep coming back to, because it changed how I think
about agent tooling.

During the v0.1.0 walkthrough, the `@token-doctor` Copilot agent —
which is just a thin orchestrator around the tokopt CLI — was
asked to audit a real Copilot template repo. As one of its
sanity-check steps, it cross-referenced `tokopt audit`'s reported
agent count against an independent shell glob of
`.github/agents/*.agent.md`. The numbers didn't match. The repo
had **9 agents totalling 8,114 tokens** under `.github/agents/`,
and `tokopt audit` was counting **zero** of them.

The bug was real. `scanAgentDefinitions` in the audit package
only walked root-level `agents/`, not `.github/agents/`. The
parallel `scanSkillDefinitions` was already symmetric; the agent
scanner had drifted out of sync. Fixed in commit
[`5ba4b9e`](https://github.com/shinyay/getting-started-with-token-optimization/commit/5ba4b9e)
of the source repo, with regression fixtures added for both code
paths. The `Fixed` and `Lesson` notes are recorded under v0.1.0 in
the source-repo
[CHANGELOG](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/CHANGELOG.md)
as evidence.

The meta-lesson is the part I want you to take away:

> **Agents that measure their own tools become test harnesses.**

If you give an agent both a measurement tool and an independent
way to cross-check the measurement, it can flag instrumentation
bugs the tool's authors missed. tokopt is now built with that
loop in mind: the CLI is the source of measurements, and the
agent and skills are encouraged to second-guess it. That's a
healthy relationship between a tool and the agent that drives it.

---

## What this version does and doesn't do

I'd rather be clear about the limits than oversell.

**This version (v0.1.0) does:**

- Scan repository config and report always-on, conditional, and
  on-demand token totals.
- Decompose a single prompt into the seven canonical segments.
- Run a fixed set of conservative, rule-based anti-pattern
  detectors.
- Read a usage log and report heavy-tail percentiles + top-N
  outliers.
- Combine audit + detect into a single dashboard, with an
  optional CI-friendly threshold.
- Use `tiktoken` (`o200k_base` by default) as a vendor-neutral
  tokenizer.

**This version does *not*:**

- Read live telemetry. There is no SDK, no daemon, no log
  shipper. If you want percentiles, you bring the log.
- Call any LLM. Ever. tokopt is offline by design.
- Rewrite your prompts. It surfaces findings; humans rewrite.
- Speak any language other than English in the docs. The CLI
  output is also English-only for now.
- Give you a byte-perfect token count for non-OpenAI model
  families. The number is a stable, reproducible approximation —
  good for *deltas*, not for billing reconciliation.

The honest list of what's coming and what isn't lives in
[roadmap.md](roadmap.md).

---

## Acknowledgements

tokopt was developed in close collaboration with **GitHub
Copilot**, particularly through the
[`@token-doctor`](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/agents/token-doctor.agent.md)
agent that ended up catching the audit bug above. The "agents that
measure their own tools become test harnesses" insight didn't come
from a planning meeting; it came from watching the agent do it.

The conceptual material — sixteen chapters on what tokens are, the
context window, the economics, the heavy tail, the hygiene
principles — lives at
<https://github.com/shinyay/getting-started-with-token-optimization>.
That repo is where this CLI was forged, and it's the place to go
if you want the long-form *why* behind every measurement tokopt
takes. This binary distribution is the *practical* counterpart;
the source repo is the *conceptual* one.

Thanks to everyone who let me run `tokopt audit` on their repos
during the v0.1.0 cycle. The numbers were always more interesting
than anyone expected, and the conversations they started are most
of the reason this tool exists in shippable form at all.
