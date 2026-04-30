# tokopt

> **Measure your LLM token bill before it measures you.**

[![Latest release](https://img.shields.io/github/v/release/shinyay/tokopt?label=release&color=blue)](https://github.com/shinyay/tokopt/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-linux%20%C2%B7%20macOS%20%C2%B7%20windows-lightgrey)](docs/installation.md)
[![Quick start](https://img.shields.io/badge/docs-quick%20start-brightgreen)](docs/quickstart.md)

`tokopt` is a small Go CLI that **measures** the token cost of a Copilot/agent
repository and reports it honestly. It scans your real configuration, decomposes
real prompts into their seven canonical segments, runs anti-pattern detectors
against real files, and analyses usage logs for the heavy tail. Output is in
**tokens** — never dollars — because pricing changes too fast and the honest
unit for design is the token.

It is built for engineers and platform teams who own a Copilot/agent template
repo and want a number, not an opinion. Every finding is labelled **measured**
or **heuristic** so you always know which numbers came from a tokenizer and
which came from pattern-matching. You can reach the same audit in three ways:
from the integrated **terminal**, from one-click **VS Code Tasks**, or from
natural-language **Copilot Chat** via the companion skills + `token-doctor`
agent. Pick whichever surface fits the moment — they all call the same binary.

## 📦 Install in one line

**bash / zsh:**

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
```

**fish:**

```fish
sh -c 'curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh'
```

**Pin to a specific version:**

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh -s -- --version v0.1.0
```

The installer detects your OS/architecture, downloads the matching binary from
the latest GitHub Release, and drops it on your `PATH`. Manual download,
checksum verification, custom prefix, Windows instructions, and uninstall are
all covered in [docs/installation.md](docs/installation.md).

## ⚡ 30-second demo

```bash
# 1. Audit any repo for its always-on / conditional / on-demand token tax.
$ tokopt audit .
tokopt audit  root=.  encoding=o200k_base
always-on tax: 103 tokens
conditional:   464 tokens (paid only when triggered: applyTo, agent step, agent invoked)
on-demand:     2701 tokens (skills loaded only when matched)

TOKENS  BYTES  SCOPE        CATEGORY              PATH                              NOTE
103     428    always-on    copilot-instructions  .github/copilot-instructions.md   
464     1974   conditional  agent-definition      agents/token-doctor.agent.md      agent definition; cost paid only when agent is invoked
669     2713   on-demand    skill-definition      skills/antipattern-scan/SKILL.md  skill is loaded on demand by description match
...

# 2. Decompose a hypothetical prompt into the seven canonical segments.
$ tokopt anatomy --always-on examples/always-on.txt --user examples/user-message.txt
tokopt anatomy  encoding=o200k_base  total input=481 tokens

SEGMENT    TOKENS  BYTES  % OF INPUT
system     0       0      0.0%
always-on  407     1865   84.6%
tools      0       0      0.0%
history    0       0      0.0%
retrieved  0       0      0.0%
user       74      341    15.4%
reasoning  0       0      0.0%

# 3. Flag anti-patterns in the static config.
$ tokopt detect .
tokopt detect: no anti-patterns found
```

That's it — three commands, no API keys, no telemetry, no network calls. The
tokenizer is local (`tiktoken-go`, `o200k_base` by default).

> **What the labels mean.** `always-on` is paid on every call (top-level
> instructions). `conditional` is paid only when triggered (agent steps,
> `applyTo`-scoped instructions). `on-demand` is paid only when matched
> (skills loaded by description). The audit reports all three so you can
> tell which knob to turn.

## 📦 What's in the box

Six commands cover the audit → diagnose → recommend loop. Each links to its
own reference doc.

| Command | Purpose | Doc |
| --- | --- | --- |
| `audit` | Repo-wide always-on / conditional / on-demand token tax. | [docs/commands/audit.md](docs/commands/audit.md) |
| `anatomy` | Decompose a prompt into the seven canonical segments. | [docs/commands/anatomy.md](docs/commands/anatomy.md) |
| `detect` | Run anti-pattern detectors against static config. | [docs/commands/detect.md](docs/commands/detect.md) |
| `tail` | p50 / p90 / p95 / p99 / max + outliers from a JSONL or CSV usage log. | [docs/commands/tail.md](docs/commands/tail.md) |
| `report` | Combined audit + detect dashboard with ranked recommendations. CI-friendly via `--threshold`. | [docs/commands/report.md](docs/commands/report.md) |
| `count` | Token count for any file. Use `-` for stdin. | [docs/commands/count.md](docs/commands/count.md) |

Global flags: `--encoding {o200k_base,cl100k_base}`, `--format {text,json,md}`,
`--reference-window N` (opt-in only — no default model size is implied). See
[docs/reference/cli-reference.md](docs/reference/cli-reference.md).

## 🧭 Three ways to use it

| Layer | Surface | When you want it |
| --- | --- | --- |
| **1 · Terminal** | `tokopt` on your shell | Scripted runs, CI gates, ad-hoc audits — see [docs/quickstart.md](docs/quickstart.md). |
| **2 · VS Code Tasks** | One-click runs from the command palette | Repeated audits during a refactor — see [docs/integrations/vscode-tasks.md](docs/integrations/vscode-tasks.md). |
| **3 · Copilot Chat** | `@token-doctor` agent + 5 skills | Natural-language audits ("why is my always-on tax so high?") — see [docs/integrations/copilot-skills-and-agent.md](docs/integrations/copilot-skills-and-agent.md). |

All three call the same binary and produce the same numbers. The skills + agent
just translate the output into prose and refuse to invent counts the CLI did
not measure.

## 🚫 What it does *not* do

- **No dollar amounts.** Pricing changes too fast; design with tokens, not
  currency. Use your provider's bill for billing.
- **No baked-in context window.** The percentage-of-window display is opt-in
  via `--reference-window N`. The tool refuses to imply a model size.
- **No cross-provider billing accuracy.** The tokenizer is `tiktoken-go`. For
  non-OpenAI model families it's a *local approximation* — useful for relative
  comparisons and before/after diffs, never as a billing oracle.
- **No telemetry, no network calls.** Everything runs locally against the
  files in your repo.

## 📚 Documentation map

The canonical entry point is **[docs/index.md](docs/index.md)** — a Diátaxis-organised
hub linking every doc below.

### 🚀 Get started
- [docs/quickstart.md](docs/quickstart.md) — zero to first audit in 5 minutes.
- [docs/installation.md](docs/installation.md) — install script, manual download, Windows, uninstall.

### 📖 Concepts
- [docs/what-is-tokopt.md](docs/what-is-tokopt.md) — one-pager: what it is, what it isn't.
- [docs/motivation.md](docs/motivation.md) — why measurement-driven, not prescriptive.
- [docs/concepts/always-on-tax.md](docs/concepts/always-on-tax.md) — what the audit is actually counting.
- [docs/concepts/three-layer-model.md](docs/concepts/three-layer-model.md) — always-on / conditional / on-demand.
- [docs/commands/anatomy.md](docs/commands/anatomy.md) — the seven canonical prompt segments.
- [docs/concepts/token-vocabulary.md](docs/concepts/token-vocabulary.md) — tokens, tokenizers, encodings.

### 📋 Commands & reference
- [docs/commands/](docs/commands/) — one page per command: `audit`, `anatomy`, `detect`, `tail`, `report`, `count`.
- [docs/reference/cli-reference.md](docs/reference/cli-reference.md) — `--encoding`, `--format`, `--reference-window`, full flag matrix.
- [docs/reference/exit-codes.md](docs/reference/exit-codes.md) — `0` = ok, `1` = error, `2` = budget exceeded.
- [docs/reference/output-formats.md](docs/reference/output-formats.md) — `text`, `json`, `md` schemas.

### 🛠 How-to
- [docs/use-cases/auditing-a-template-repo.md](docs/use-cases/auditing-a-template-repo.md)
- [docs/use-cases/ci-budget-gating.md](docs/use-cases/ci-budget-gating.md)
- [docs/use-cases/pr-review-with-tokopt.md](docs/use-cases/pr-review-with-tokopt.md)
- [docs/use-cases/prompt-anatomy-investigation.md](docs/use-cases/prompt-anatomy-investigation.md)
- [docs/use-cases/monitoring-token-spend.md](docs/use-cases/monitoring-token-spend.md)
- [docs/integrations/vscode-tasks.md](docs/integrations/vscode-tasks.md)
- [docs/integrations/copilot-skills-and-agent.md](docs/integrations/copilot-skills-and-agent.md)
- [docs/integrations/github-actions.md](docs/integrations/github-actions.md)

### 🔭 Project
- [docs/roadmap.md](docs/roadmap.md)
- [docs/faq.md](docs/faq.md)
- [docs/troubleshooting.md](docs/troubleshooting.md)
- [docs/glossary.md](docs/glossary.md)

### 🤝 Community
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [SECURITY.md](SECURITY.md)

## 🚦 CI integration

Use `tokopt report --threshold N` to fail a build when the always-on tax grows
past your budget:

```yaml
- name: Token budget
  run: tokopt report --threshold 1500 .
```

Exit code `0` if the always-on tax stays under budget, `2` if exceeded, `1` for
runtime errors. The gate is on **always-on only** — conditional and on-demand
totals are reported but never gated by `--threshold`, because they are not paid
on every call. Full recipe: [docs/integrations/github-actions.md](docs/integrations/github-actions.md).

## 🎯 Why measurement-driven?

Most token-optimization advice is prescriptive prose: "cut prompts by 40%",
"trim your tools", "summarise your history". Useful — but the reader is left
guessing whether it applies to *their* repo and whether their fix actually
moved the needle. `tokopt` closes that gap by pairing every recommendation
with a measured token count, or labelling it **heuristic** when impact can
only be inferred from static config. Read the long version in
[docs/motivation.md](docs/motivation.md).

## 🔭 Roadmap

`v0.1` ships the audit / anatomy / detect / tail / report / count loop;
upcoming work is tracked in [docs/roadmap.md](docs/roadmap.md).

## License

MIT — see [LICENSE](LICENSE).

---

Built by [@shinyay](https://github.com/shinyay) with the help of GitHub Copilot.
