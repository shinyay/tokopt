# tokopt — documentation

Welcome to the documentation hub for **tokopt**, a small Go CLI that
measures the token cost of LLM-facing files in your repository. This
page is the front door to the docs that ship with the binary
distribution. The docs are organised by the [Diátaxis][diataxis]
quadrants — *tutorials*, *how-to guides*, *reference*, and
*explanation* — so you can pick the right kind of page for the kind of
question you have in front of you right now.

[diataxis]: https://diataxis.fr/

If you're after the conceptual material — what tokens are, why they
matter, the chapter-length treatment — that lives in the source repo:
<https://github.com/shinyay/getting-started-with-token-optimization>.
This repo is the *binary + docs* distribution; that one is the
*guide + tools* monorepo where tokopt was forged.

---

## Reading paths

Three suggested paths, depending on what you're trying to do.

### "I just want to try it"

You want to see numbers on your own repo, fast. Five minutes, no
theory.

- [quickstart.md](quickstart.md) — install the binary, run your
  first command.
- [commands/audit.md](commands/audit.md) — your first audit on a
  real repo.
- [commands/count.md](commands/count.md) — count tokens in a single
  file, the simplest possible smoke test.
- [troubleshooting.md](troubleshooting.md) — if something goes
  sideways on the first run.

### "I want to understand it"

You want the mental model before you wire it into anything.

- [motivation.md](motivation.md) — the "why I made this" story.
- [what-is-tokopt.md](what-is-tokopt.md) — the one-page elevator.
- [concepts/three-layer-model.md](concepts/three-layer-model.md) —
  always-on / conditional / on-demand.
- [concepts/always-on-tax.md](concepts/always-on-tax.md) — the cost
  you pay on every single call.
- [commands/anatomy.md](commands/anatomy.md) — the
  seven canonical segments of an LLM call.
- [concepts/token-vocabulary.md](concepts/token-vocabulary.md) —
  tokens, tokenizers, encodings.
- [reference/cli-reference.md](reference/cli-reference.md) — the
  command reference, read end-to-end.

### "I want to operationalise it"

You've decided tokopt is useful and you want it in your workflow,
your CI, and your team's hands.

- [installation.md](installation.md) — install paths for macOS,
  Linux, Windows, and CI runners.
- [integrations/github-actions.md](integrations/github-actions.md) — wire `tokopt report
  --threshold` into a per-PR token budget.
- [integrations/vscode-tasks.md](integrations/vscode-tasks.md) —
  one-click invocations from the VS Code Run Task menu.
- [integrations/copilot-skills-and-agent.md](integrations/copilot-skills-and-agent.md) —
  reach tokopt from Copilot Chat through skills and an agent.
- [use-cases/ci-budget-gating.md](use-cases/ci-budget-gating.md) — fail the
  build when always-on tax grows past budget.
- [use-cases/pr-review-with-tokopt.md](use-cases/pr-review-with-tokopt.md) — review a
  PR with tokopt: did it make the always-on tax worse?
- [reference/exit-codes.md](reference/exit-codes.md),
  [reference/output-formats.md](reference/output-formats.md),
  [maintainer/release.md](maintainer/release.md) — the small print.

---

## Table of contents (by Diátaxis quadrant)

### Tutorials — learning-oriented

Hand-holding pages. You follow along; at the end, the thing works
and you've seen it work.

- [quickstart.md](quickstart.md) — zero to a measured audit in five
  minutes.

### How-to guides — problem-oriented

Recipes for a specific outcome. You arrive with a goal; you leave
with the steps to reach it.

- [use-cases/ci-budget-gating.md](use-cases/ci-budget-gating.md)
- [use-cases/pr-review-with-tokopt.md](use-cases/pr-review-with-tokopt.md)
- [use-cases/auditing-a-template-repo.md](use-cases/auditing-a-template-repo.md)
- [use-cases/prompt-anatomy-investigation.md](use-cases/prompt-anatomy-investigation.md)
- [use-cases/monitoring-token-spend.md](use-cases/monitoring-token-spend.md)
- [integrations/github-actions.md](integrations/github-actions.md)
- [integrations/vscode-tasks.md](integrations/vscode-tasks.md)
- [integrations/copilot-skills-and-agent.md](integrations/copilot-skills-and-agent.md)

### Reference — information-oriented

Exhaustive, dry, accurate. Look something up; close the tab.

- [reference/cli-reference.md](reference/cli-reference.md) — single-page
  consolidated reference for every command and flag.
- [commands/audit.md](commands/audit.md)
- [commands/anatomy.md](commands/anatomy.md)
- [commands/detect.md](commands/detect.md)
- [commands/tail.md](commands/tail.md)
- [commands/report.md](commands/report.md)
- [commands/count.md](commands/count.md)
- [reference/exit-codes.md](reference/exit-codes.md)
- [reference/output-formats.md](reference/output-formats.md)
- [reference/encodings.md](reference/encodings.md)

### Explanation — understanding-oriented

The "why", the mental model, the design choices. Read for context;
not a step-by-step.

- [what-is-tokopt.md](what-is-tokopt.md)
- [motivation.md](motivation.md)
- [concepts/three-layer-model.md](concepts/three-layer-model.md)
- [concepts/always-on-tax.md](concepts/always-on-tax.md)
- [concepts/token-vocabulary.md](concepts/token-vocabulary.md)

### Maintainer

For people cutting a release of the binary.

- [maintainer/release.md](maintainer/release.md) — end-to-end release runbook.

---

## Project meta

Housekeeping pages — the kind every repo has, in one place.

- [../CHANGELOG.md](../CHANGELOG.md) — what shipped, when.
- [roadmap.md](roadmap.md) — what's coming next, what isn't.
- [faq.md](faq.md) — questions that come up often.
- [troubleshooting.md](troubleshooting.md) — when the binary
  refuses to cooperate.
- [glossary.md](glossary.md) — the vocabulary the docs assume.
- [../CONTRIBUTING.md](../CONTRIBUTING.md) — how to file issues
  against this distribution.
- [../CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md)
- [../SECURITY.md](../SECURITY.md) — how to report a security issue.

---

Ready? If you just want it working, start with
[quickstart.md](quickstart.md). If you want to know what you're
about to install, start with [what-is-tokopt.md](what-is-tokopt.md).
