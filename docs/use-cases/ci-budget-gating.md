# CI budget gating

How to fail a pull request when it pushes the always-on token tax above
a budget you defined.

---

## Problem

Your repo's `.github/copilot-instructions.md` and `AGENTS.md` are loaded
on **every** chat turn, by every contributor, forever. A well-meaning PR
can add 1,000 tokens to that floor and nobody notices until the bill
shows up. You want CI to refuse the merge instead.

## Who this is for

- Repo maintainers who own a Copilot template, an internal agent
  toolkit, or any project where contributors edit `copilot-instructions.md`
  or `AGENTS.md`.
- Platform / DX teams enforcing a per-repo always-on budget across many
  projects.

## What you'll need

- A GitHub repository with Actions enabled.
- `tokopt` v0.1.0 or later (the workflow installs it for you).
- A baseline measurement (one run of `tokopt audit .` on `main`).
- Five minutes.

---

## Steps

### 1. Pick a budget

Run an audit locally to see what you're starting from:

```bash
tokopt audit .
```

You'll get a header like:

```text
tokopt audit  root=.  encoding=o200k_base
always-on tax: 2532 tokens
conditional:   11414 tokens (paid only when triggered: applyTo, agent step, agent invoked)
on-demand:     38397 tokens (skills loaded only when matched)
```

The first number — `always-on tax` — is the only one the CI gate
budgets. Conditional and on-demand totals are *not* gated, by design
(see [`../commands/report.md`](../commands/report.md#exit-codes)).

Pick a budget that is `current_baseline + 10–20%` of headroom. For the
2,532-token baseline above, **3,000 tokens** is a reasonable starting
threshold: it permits small additions, but a thousand-token bloat is
caught.

> [!TIP]
> Don't pick the baseline itself as the budget. Even noise from a
> tokenizer-version bump or a one-line README tweak that lands in an
> always-on file would trip the gate. Leave 10–20% of breathing room.

### 2. Add the workflow file

Drop the supplied workflow into `.github/workflows/`:

```bash
mkdir -p .github/workflows
curl -fsSL \
  https://raw.githubusercontent.com/shinyay/tokopt/main/examples/github-workflows/token-budget.yml \
  -o .github/workflows/token-budget.yml
```

The default file gates at 800 tokens. Open it and change the threshold
on the **last step** to your chosen budget:

```yaml
- name: Enforce always-on token budget
  run: tokopt report . --threshold 3000
```

### 3. Verify the install step

The workflow's install step pins a tagged release so the gate is
reproducible:

```yaml
- name: Install tokopt
  run: |
    curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \
      | sh -s -- --version v0.1.0
    echo "$HOME/.local/bin" >> "$GITHUB_PATH"
```

Always pin a version. An unpinned `--version main` install means a
tokenizer change in tokopt itself can flip your gate without any change
in your repo — which makes the gate useless as a quality signal.

### 4. Run the gate locally first

Before opening the PR, dry-run the exact command CI will run:

```bash
tokopt report . --threshold 3000
echo "exit=$?"
```

If `exit=0`, you're under budget. If `exit=2`, the threshold was
violated and stderr carries the message:

```text
tokopt: always-on tax 3140 exceeds threshold 3000
```

Note the exit code: `report` uses **strict greater-than**, so an
`always_on_total` of exactly `3000` passes. See
[`../commands/report.md`](../commands/report.md) for the full contract.

### 5. Verify the failure mode

This is the test that matters: prove the gate actually blocks bad PRs.

1. On a throwaway branch, append ~1,000 tokens of filler to
   `.github/copilot-instructions.md`:

   ```bash
   yes "This is a long instruction that exists only to inflate the file." \
     | head -200 >> .github/copilot-instructions.md
   ```

2. Open a PR. The `tokopt budget gate` job should run and fail with the
   stderr line above and a red ❌ check on the PR.

3. Confirm the failure is on the `Enforce always-on token budget` step
   (exit code 2), not on the audit step (which is informational and
   always exits 0).

4. Revert the throwaway branch and close the PR. The gate is now real.

### 6. Add the audit as a parallel step (already in the template)

The supplied workflow already includes a separate `Audit always-on
token cost` step that runs **before** the gate:

```yaml
- name: Audit always-on token cost
  run: tokopt audit .
```

Keep it. When the gate fails, the audit output a few lines above tells
the PR author *which file* grew, not just that the budget tripped. This
is the difference between a useful CI failure and an annoying one.

---

## Expected outcome

| Scenario                                                  | Audit step | Gate step | PR check |
|-----------------------------------------------------------|------------|-----------|----------|
| PR is under budget                                        | exit 0     | exit 0    | ✅ green  |
| PR is over budget                                         | exit 0     | exit 2    | ❌ red    |
| `copilot-instructions.md` is missing entirely             | exit 0     | exit 0    | ✅ green  |
| `tokopt` install step itself fails (network, bad version) | n/a        | n/a       | ❌ red    |

Note that `audit` is always green: it's informational. The only step
that can flip the PR check on a budget violation is the
`tokopt report . --threshold N` step.

---

## Variations

### Monorepo: gate per subtree

If your repo hosts multiple Copilot templates under, e.g., `packages/`,
budget each one independently. Run a matrix job and use a per-package
threshold:

```yaml
strategy:
  matrix:
    package:
      - { path: packages/web,    threshold: 1500 }
      - { path: packages/server, threshold: 2200 }
      - { path: packages/cli,    threshold: 1000 }
steps:
  - run: tokopt report ${{ matrix.package.path }} --threshold ${{ matrix.package.threshold }}
```

Each package owns its own always-on budget. A bloated `web` package
does not trip the `cli` gate.

### Per-team budgets via labels

Set the threshold from a PR label so different teams can dial their
own headroom:

```yaml
- name: Resolve threshold from labels
  id: budget
  run: |
    case "${{ join(github.event.pull_request.labels.*.name, ',') }}" in
      *team-platform*) echo "value=1500" >> "$GITHUB_OUTPUT" ;;
      *team-product*)  echo "value=3000" >> "$GITHUB_OUTPUT" ;;
      *)               echo "value=2000" >> "$GITHUB_OUTPUT" ;;
    esac
- run: tokopt report . --threshold ${{ steps.budget.outputs.value }}
```

### Advisory mode (first 30 days)

Don't surprise the team. Run the gate but let the build pass while you
gather data:

```yaml
- name: Enforce always-on token budget (advisory)
  continue-on-error: true
  run: tokopt report . --threshold 3000
```

After a few weeks of green/yellow signal, drop `continue-on-error` and
the gate becomes blocking. This is the lowest-friction way to introduce
a budget without rolling back contributors' work-in-progress.

---

## What to read next

- [`auditing-a-template-repo.md`](auditing-a-template-repo.md) — a
  case-study walkthrough of picking a baseline before you set a budget.
- [`pr-review-with-tokopt.md`](pr-review-with-tokopt.md) — manual
  review recipes that complement the automated gate.
- [`../commands/report.md`](../commands/report.md) — full reference for
  `--threshold`, exit codes, and JSON / Markdown output formats.
- [`../commands/audit.md`](../commands/audit.md) — the audit step the
  gate is built on.
- [`../concepts/three-layer-model.md`](../concepts/three-layer-model.md)
  — why only the always-on layer is gated.
