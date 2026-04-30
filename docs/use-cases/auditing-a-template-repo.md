# Auditing a template repo

How to figure out what a third-party Copilot template is actually
costing you, before you commit to it (or after you've inherited it).

---

## Problem

You've cloned a community Copilot template — the one with "25 skills,
9 agent personas, opinionated AGENTS.md, ready out of the box". You
have no idea what gets loaded on every chat turn vs. what's lazy. You
want a measurement-first answer, not a vibes-based one.

## Who this is for

- Engineers evaluating a Copilot starter / template repo before
  adopting it.
- Maintainers who forked an active template and want to see what
  upstream just dragged into their always-on tax.
- Anyone debugging "why is my Copilot context so big?" on a template
  they didn't write.

## What you'll need

- The template cloned locally.
- `tokopt` v0.1.0 or later, installed and on `$PATH`. Verify with
  `tokopt --version`.
- A shell that can do globs (bash, zsh, fish).
- 10–15 minutes for the full audit → diagnose → triage cycle.

---

## Steps

### 1. Clone the template and orient yourself

```bash
git clone https://github.com/<owner>/<copilot-template>.git
cd <copilot-template>
ls .github/ AGENTS.md skills/ agents/ 2>/dev/null
```

You're looking for the canonical Copilot config locations:
`.github/copilot-instructions.md`, `AGENTS.md`, `.github/AGENTS.md`,
`.github/instructions/*.instructions.md`, `agents/*.agent.md`,
`.github/agents/*.agent.md`, `skills/*/SKILL.md`,
`.github/skills/*/SKILL.md`. The full list is in
[`../commands/audit.md`](../commands/audit.md#files-audited).

### 2. Get the headline numbers

```bash
tokopt audit .
```

A real run on a 26-skill / 9-agent template printed:

```text
tokopt audit  root=.  encoding=o200k_base
always-on tax: 2532 tokens
conditional:   11414 tokens (paid only when triggered: applyTo, agent step, agent invoked)
on-demand:     38397 tokens (skills loaded only when matched)
```

Read it like this:

- **2,532 always-on tokens** are paid on **every** chat turn — even a
  one-word "thanks". 50 turns/day = 126,600 tokens/day spent before any
  actual work.
- **11,414 conditional tokens** are paid *only* when an `applyTo` glob
  matches or an agent is invoked. Worst case (every trigger fires); in
  practice a small subset.
- **38,397 on-demand tokens** are 26 skills that load only on
  description match. Total looks scary; per-turn cost is usually 0–1
  skills.

The always-on number is the one you defend. The other two are upper
bounds — see
[`../concepts/three-layer-model.md`](../concepts/three-layer-model.md).

### 3. Surface anti-patterns

```bash
tokopt detect .
```

On the same template, two findings:

```text
[INFO] AGENTS.md is large (huge-agents-md, measured)
  location: AGENTS.md
  evidence: 1416 tokens
  fix:      Trim to landmines and conventions; push how-tos into on-demand docs.
  saves:    up to ~916 tokens (target 500)

[WARN] System prompt is doing too much (kitchen-sink-system-prompt, measured)
  location: .github/copilot-instructions.md
  evidence: 1116 tokens
  fix:      Cut to smallest behaviour-changing rules; push detail into on-demand skills.
  saves:    up to ~616 tokens (target 500)
```

The four severity levels (`info`, `warn`, `high`, `critical`) are
defined in [`../commands/detect.md`](../commands/detect.md#detectors).
Note that `detect` exits **0 even when findings exist** — it's
informational. Gating is `report`'s job.

Together the two findings predict: trim those two files and the
always-on tax drops from **2,532 → ~1,000 tokens** (~60% reduction).

### 4. Cross-check: the bug-catch moment

This is the most important step in any first-time audit. **Don't trust
the tool. Verify it.**

Independently glob the agent files yourself and sum their sizes:

```bash
for f in .github/agents/*.agent.md; do
  tokopt count "$f"
done
```

Sample output from the same template:

```text
.github/agents/token-doctor.agent.md         464 tokens   2102 bytes  (o200k_base)
.github/agents/planner.agent.md              644 tokens   2877 bytes  (o200k_base)
.github/agents/reviewer.agent.md             655 tokens   2941 bytes  (o200k_base)
.github/agents/implementer.agent.md          656 tokens   2980 bytes  (o200k_base)
.github/agents/docs-writer.agent.md          721 tokens   3185 bytes  (o200k_base)
.github/agents/compliance.agent.md           777 tokens   3441 bytes  (o200k_base)
.github/agents/maintenance.agent.md          942 tokens   4198 bytes  (o200k_base)
.github/agents/security-hardening.agent.md   996 tokens   4482 bytes  (o200k_base)
.github/agents/template-curator.agent.md    2259 tokens  10073 bytes  (o200k_base)
```

Total: **9 files, 8,114 tokens**. Now go back to step 2 and check that
the conditional bucket reflects this. It should — but in **tokopt
v0.1.0-pre**, it didn't.

> [!IMPORTANT]
> **The bug-catch story.** During the v0.1.0 development cycle, an LLM
> agent (`token-doctor`) ran exactly this cross-check and noticed that
> `tokopt audit`'s conditional bucket was reporting **0** tokens for
> the 9 agent files it had just enumerated by hand. The `audit` command
> was scanning `agents/*.agent.md` (root level) but **not**
> `.github/agents/*.agent.md` — silently under-reporting conditional
> tokens by 8,114 on every template that uses the `.github/`
> convention.
>
> The fix landed in commit `5ba4b9e` of the source guide repo: the
> `scanAgentDefinitions` function now scans both `agents/` and
> `.github/agents/`, mirroring `scanSkillDefinitions`. Regression
> fixtures cover both layouts.
>
> **The lesson is general, not about this specific bug.** An agent
> compared a tool's output to ground truth it gathered itself — and
> that single habit caught a measurement bug the tool's authors had
> shipped. Build agents that cross-check their own tools and they
> become unintentional test harnesses. See
> [the source CHANGELOG](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/CHANGELOG.md)
> for the full write-up.

When you run this audit on your template today (with `tokopt` ≥ 0.1.0),
the numbers should agree. **If they don't, file an issue.**

### 5. Drill into the largest always-on file

The two `detect` findings already named the suspects. To see *where*
inside `copilot-instructions.md` the bytes are going, dump it through
`anatomy` in single-segment mode:

```bash
tokopt anatomy --always-on .github/copilot-instructions.md
```

This treats the file as a one-segment prompt, so the per-segment table
collapses to one informative line and the byte/token totals match
`tokopt count`. It's a sanity check, not the main use of `anatomy` —
the richer use is the [prompt-anatomy investigation
recipe](prompt-anatomy-investigation.md).

For *structural* bloat (sections, headings, lists), use a regular
text editor and the `tokopt count` output as your scorecard:

```bash
tokopt count .github/copilot-instructions.md
# .github/copilot-instructions.md  1116 tokens  4983 bytes  (o200k_base)
```

Cut a section, re-count, repeat.

### 6. Decide what to keep, move, or delete

This step is **human judgement**. tokopt does not automate it. The
prior steps gave you:

- a per-turn tax to defend (2,532 → target ~1,000),
- two named offenders (`AGENTS.md`, `.github/copilot-instructions.md`),
- a measured savings ceiling for each (~916 + ~616 = ~1,532 tokens),
- a per-file outlier in the conditional bucket
  (`template-curator.agent.md` at 2,259 tokens — 2–3× its peer
  agents).

A reasonable triage plan looks like:

1. **Trim** `AGENTS.md` from 1,416 → ~500 tokens. Keep only landmines
   and conventions; move "how to use this template" into a README.
2. **Trim** `.github/copilot-instructions.md` from 1,116 → ~500 tokens.
   Keep behaviour-shaping rules only; move project facts into
   on-demand skills or `.github/instructions/*.instructions.md` with
   tight `applyTo` globs.
3. **Inspect** `template-curator.agent.md` — it's not always-on, so the
   per-turn impact is conditional, but a 2,259-token agent is worth a
   read-through. Often it has accumulated rules better expressed as a
   skill.
4. **Leave** the 26 skills alone (for now). They cost zero per turn
   when they don't match. The risk is *misfire*, not *cost* — and
   misfire is best fixed by tightening skill `description:` frontmatter,
   not by deleting files.

### 7. Re-audit to confirm

After every trim:

```bash
tokopt audit .
```

The `always-on tax` line is your scorecard. On the case-study repo,
trimming `AGENTS.md` alone (1,416 → 478 tokens) dropped the always-on
bucket from **2,532 → 1,594** — a single PR's worth of work, paid back
on every conversation, forever.

---

## Expected outcome

You can answer four questions about a template you didn't write:

1. What's the per-turn tax? (always-on number)
2. What does `detect` flag, and is it credible? (1–2 measured findings,
   usually)
3. Does the audit agree with my own ground-truth glob? (yes — and if
   not, that *is* the finding)
4. What's a realistic post-trim target? (always-on minus the sum of
   `est_tokens_saved` from measured findings)

---

## Variations

### Template-shopping: score before committing

Comparing three candidate templates before adopting one? Run the same
audit on each and stack the always-on numbers:

```bash
for repo in template-a template-b template-c; do
  ( cd "$repo" && echo "== $repo ==" && tokopt audit . | head -4 )
done
```

The lowest always-on number isn't automatically the winner — the
template might be missing capabilities you need — but the always-on
floor *is* a tax you'll pay every day, so it earns the first column
of your decision matrix.

### Forked-but-tracking: diff against upstream

You forked an active template and want to know what upstream's last
release added to your tax:

```bash
git checkout upstream/main -- .
tokopt audit . --format json > audit.upstream.json
git checkout HEAD -- .
tokopt audit . --format json > audit.fork.json
diff <(jq '.always_on_total' audit.upstream.json) \
     <(jq '.always_on_total' audit.fork.json)
```

Run this on every upstream merge. A jump of 200+ tokens on the
always-on line is worth a manual review.

### Building your own template: gate it

If you're publishing a template for others to use, your contributors
will edit `copilot-instructions.md` over time. Set a CI gate (see
[`ci-budget-gating.md`](ci-budget-gating.md)) so the always-on tax you
audited today is the same one your users get six months from now.

---

## What to read next

- [`prompt-anatomy-investigation.md`](prompt-anatomy-investigation.md)
  — drill into a single prompt instead of the whole repo.
- [`pr-review-with-tokopt.md`](pr-review-with-tokopt.md) — apply this
  audit to PR diffs.
- [`ci-budget-gating.md`](ci-budget-gating.md) — make the floor stick.
- [`../commands/audit.md`](../commands/audit.md),
  [`../commands/detect.md`](../commands/detect.md),
  [`../commands/count.md`](../commands/count.md) — full command refs.
- [`../concepts/three-layer-model.md`](../concepts/three-layer-model.md)
  — the bucket model the audit is built on.
- Source repo —
  [Case study: diagnosing a real Copilot template](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/case-study-template-repo.md)
  and
  [VS Code walkthrough](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/walkthrough-vscode.md)
  — the long-form session this recipe is distilled from.
