# Copilot Chat — Skills and Agent Bridge

## Problem

You want `tokopt` available inside **Copilot Chat** in VS Code — so you
can ask "audit this repo" in plain language and have the right command
run, with its output explained — instead of switching to a terminal.

> **Important.** This repository ships only the `tokopt` binary. The
> Copilot Chat **skills** and **custom agent** that put `tokopt` in
> chat live in a **separate, dedicated source repository**:
> <https://github.com/shinyay/getting-started-with-token-optimization>.
>
> This page is a *bridge*: it explains the relationship and walks you
> through installing the chat-surface pieces from that repo.

---

## The architecture in 3 sentences

1. **`tokopt` is the measurement primitive** — a CLI that counts tokens,
   detects anti-patterns, and prints budgets. It has no opinions about
   editors or chat.
2. **The skills + agent are the chat-surface UX** — small Markdown files
   that teach Copilot Chat *when* to invoke `tokopt`, *which*
   sub-command to run, and *how* to summarise the output.
3. **They shell out to `tokopt` under the hood**, so the chat layer only
   works once the CLI is installed and on `PATH`. The skills/agent live
   in the conceptual guide repo because they're tightly coupled to that
   pedagogical material — keeping each repo single-purpose.

---

## Where the skills + agent live

Source repo: <https://github.com/shinyay/getting-started-with-token-optimization>

| Kind | Path in source repo | Count |
|---|---|---|
| Skills | `skills/<name>/SKILL.md` | 5 |
| Custom agent | `agents/token-doctor.agent.md` | 1 |

The five skills are:

- `token-audit`
- `prompt-anatomy`
- `antipattern-scan`
- `hygiene-coach`
- `heavy-tail`

The single agent is `token-doctor` — an orchestrator persona that calls
the skills in sequence to do an end-to-end audit-and-recommend pass.

---

## Prerequisites

- **`tokopt` installed and on `PATH`.** Verify with `tokopt --version`.
  If not installed, follow [../installation.md](../installation.md).
- **VS Code Insiders.** Custom-agent and skill discovery are still
  evolving; the Insider build tracks the latest behaviour.
- **GitHub Copilot Chat extension** enabled, in **agent mode**, with
  the `bash` tool allowed (the skills shell out to `tokopt`).

---

## Install the skills

```bash
# 1. Clone the source repo somewhere outside your project.
git clone https://github.com/shinyay/getting-started-with-token-optimization \
  ~/src/getting-started-with-token-optimization

# 2. Copy the skills into the consumer repo's .github/skills/ tree.
#    (.github/skills/ is the convention current VS Code Copilot scans.)
cd /path/to/your-repo
mkdir -p .github/skills
cp -r ~/src/getting-started-with-token-optimization/skills/* .github/skills/
```

Each skill ends up at `.github/skills/<name>/SKILL.md`.

For other install scopes (per-repo at the root, user-global for the
Copilot CLI, the Cloud Agent), follow the source repo's mechanical
install guide:
<https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/installing-skills-and-agent.md>.

### Reload VS Code window

VS Code caches the skill index at startup. Newly copied files won't
appear until you reload:

```
Ctrl+Shift+P  →  Developer: Reload Window
```

### Verify

In Copilot Chat, type `#` — the five skill names should auto-complete.
Or ask Copilot directly:

```
Which skills do you have available right now?
```

`token-audit`, `prompt-anatomy`, `antipattern-scan`, `hygiene-coach`,
and `heavy-tail` should be in the list.

---

## Install the agent

```bash
mkdir -p .github/agents
cp ~/src/getting-started-with-token-optimization/agents/token-doctor.agent.md \
   .github/agents/
```

Reload the window again. The agent shows up in the agent picker.

---

## Use it from chat

1. Open Copilot Chat (`Ctrl+Alt+I` by default).
2. Open the **agent picker**:
   - **Canonical:** `Ctrl+.` (macOS: `Cmd+.`).
   - In current VS Code Insider builds, `@` opens the **file-attachment
     picker**, not the agent picker. Use `Ctrl+.` to pick `token-doctor`.
3. Pick `token-doctor` and ask, for example:
   - `このリポジトリを総合診断してください`
   - `Run a token audit on this repo and explain the result`
   - `Find the most expensive thing in my .github/copilot-instructions.md`

The agent decides which skills to invoke based on the request — typically
`token-audit` first, then `antipattern-scan`, optionally `prompt-anatomy`
on a specific file, finishing with `hygiene-coach` if you ask for fixes.

You'll see it run shell commands like `tokopt audit .` or
`tokopt detect .` in the chat thread, then quote the actual numbers
back at you (no invented totals — the agent's
[behavioural contract](https://github.com/shinyay/getting-started-with-token-optimization/blob/main/agents/token-doctor.agent.md)
forbids that).

---

## Five skills at a glance

| Skill | What it does |
|---|---|
| `token-audit` | Runs [`tokopt audit`](../commands/audit.md) and explains the always-on / conditional / on-demand split. |
| `prompt-anatomy` | Runs [`tokopt anatomy`](../commands/anatomy.md) on a specific file pair and walks through where the bytes went (7 segments). |
| `antipattern-scan` | Runs [`tokopt detect`](../commands/detect.md) and translates findings, prioritising by `severity` (info / warn / high / critical) and `confidence`. |
| `hygiene-coach` | Bundles audit + detect + suggestions into an iterative reduction loop: measure → propose ONE change → confirm → apply → re-measure. |
| `heavy-tail` | Surfaces the highest-cost outliers from a usage log via [`tokopt tail`](../commands/tail.md). |

All five share the same contract: **never claim a token cost without a
real `tokopt` invocation that produced the number.** They label findings
as `measured` vs `heuristic` rather than inventing savings estimates.

---

## Troubleshooting

### Agent doesn't appear in the picker

- Confirm the file exists: `ls .github/agents/token-doctor.agent.md`.
- Reload the window (skills/agents are indexed at startup).
- Confirm Copilot Chat **agent mode** is on in settings.
- Older VS Code stable builds may not support custom agents; switch to
  Insider.

### `command not found: tokopt` from inside the agent

The shell that Copilot spawns may not inherit your interactive `PATH`
(this is the same class of bug as the one in
[vscode-tasks.md](vscode-tasks.md#command-tokopt-not-found)).

Fix: install `tokopt` to a system-wide location (`/usr/local/bin`) so
every shell sees it, or add the install dir to your **login**-shell rc
file (not just the interactive one).

### The wrong skill triggered (or none did)

Skills are matched by **semantic similarity** to the prompt, not exact
keywords. If two skill descriptions overlap, Copilot may pick the wrong
one. Workaround: ask explicitly — `load the antipattern-scan skill and
run it`.

### `@` doesn't open the agent picker

In current VS Code Insider builds, `@` is the **file-attachment**
picker. The canonical agent picker is `Ctrl+.` (macOS: `Cmd+.`). The
source repo's `copilot-bridge.md` documents this transition in detail:
<https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/copilot-bridge.md#activation>.

### Skill installed but `#name` doesn't auto-complete

Same root cause as the previous one — the index is cached. Reload the
window once and re-test.

---

## Why aren't the skills and agent in this repo?

`tokopt` is the **tool**: a measurement primitive with one job and a
stable CLI contract. The skills and agent are the **pedagogy + UX
layer**: they teach Copilot when to use the tool and how to talk about
the output, and they evolve with the conceptual material in the guide
repo (`docs/copilot-bridge.md`,
`docs/installing-skills-and-agent.md`, walkthroughs, sample chats).

Splitting the two repos keeps each one single-purpose:

- This repo can ship a tagged binary release without touching skill
  text.
- The guide repo can iterate on chat UX, agent prompts, and tutorials
  without re-tagging the CLI.

For the philosophical background see [../motivation.md](../motivation.md).

---

## What to read next

- Source repo's bridge doc — conceptual deep-dive on skills vs agent:
  <https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/copilot-bridge.md>
- Source repo's mechanical install guide — every install scope:
  <https://github.com/shinyay/getting-started-with-token-optimization/blob/main/docs/installing-skills-and-agent.md>
- [vscode-tasks.md](vscode-tasks.md) — the same commands as one-keypress tasks
- [github-actions.md](github-actions.md) — gating CI on the same numbers
