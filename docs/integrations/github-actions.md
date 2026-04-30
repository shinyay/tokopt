# GitHub Actions

## Problem

You want every pull request to run `tokopt` against the repo and **fail
the build** if the always-on token cost exceeds a budget. The PR author
sees the violation in the checks panel and can't merge until they fix
it (or raise the budget intentionally).

This page walks through dropping in the verified workflow shipped at
[`examples/github-workflows/token-budget.yml`](https://github.com/shinyay/tokopt/blob/main/examples/github-workflows/token-budget.yml).

---

## Step 1: Copy the example workflow

Place this file at `.github/workflows/token-budget.yml` in the consumer
repo:

```yaml
# Token-budget CI gate for tokopt.
#
# Drop this file into .github/workflows/ in your repo. It installs the
# tokopt binary, runs an audit on the always-on Copilot config, and
# fails the build if the always-on tax exceeds the threshold.
name: token-budget

on:
  pull_request:
  push:
    branches: [main]

# Least-privilege: the gate only needs to read the repo.
permissions:
  contents: read

jobs:
  tokopt:
    name: tokopt budget gate
    runs-on: ubuntu-latest
    # Fail fast: surface the first violation instead of running on.
    timeout-minutes: 5
    steps:
      - name: Check out the repository
        uses: actions/checkout@v4

      - name: Install tokopt
        # Pin to a tagged release so the gate is reproducible.
        run: |
          curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \
            | sh -s -- --version v0.1.0
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
        
      - name: Audit always-on token cost
        # Informational: prints the per-file breakdown for the PR log.
        run: tokopt audit .

      - name: Enforce always-on token budget
        # Exits 2 if the always-on tax is above 800 tokens, failing the job.
        run: tokopt report . --threshold 800
```

Two things to note about the structure:

- The **install** step appends `$HOME/.local/bin` to `GITHUB_PATH`, so
  `tokopt` is on `PATH` for every subsequent step.
- The **audit** step is purely informational (always exits 0); the
  **report** step is the gate (exits 2 on violation — see
  [../commands/report.md](../commands/report.md#exit-codes)).

---

## Step 2: Pick a budget

Don't guess — measure first.

```bash
tokopt audit . --format json | jq '.always_on_total'
```

That prints the current always-on total in tokens. Use it as a baseline,
add 10–20 % headroom for organic growth, and round to a clean number.

| Current always-on | Reasonable threshold |
|---|---|
| 350 | 450 |
| 720 | 850 |
| 1 100 | 1 300 |

Hard-code the number into the workflow as `--threshold N`. Keeping it
in-tree (rather than in a secret or repo variable) makes budget changes
visible in PR diffs — which is the whole point.

---

## Step 3: Verify the workflow

Run a "tax test" before relying on it:

1. Open a throwaway PR that adds about 1 000 tokens of filler to
   `.github/copilot-instructions.md` (a few paragraphs of lorem ipsum
   will do).
2. Push and watch the **token-budget** check.
3. Confirm it fails with a non-zero exit, and the **Enforce always-on
   token budget** step prints the over-budget number.
4. Revert the filler. Push again. The check goes green.

If step 3 doesn't fail, the threshold is set higher than the filler
pushes you to — lower it and re-test.

---

## Variations

### Advisory-only mode (no gating)

Drop the `report` step (or the `--threshold` flag) entirely. The
workflow then just prints `tokopt audit .` output to the run log
without ever failing the job — useful while a team is getting used to
the numbers.

### Comment the report on the PR

Append a step that posts the human-readable report as a PR comment:

```yaml
      - name: Comment token report on PR
        if: github.event_name == 'pull_request'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          tokopt report . --format md > /tmp/report.md
          gh pr comment "${{ github.event.pull_request.number }}" \
            --body-file /tmp/report.md
```

This needs `pull-requests: write` added to the job's `permissions:`.

### Matrix per-subtree (monorepos)

Different subdirs, different budgets:

```yaml
    strategy:
      matrix:
        include:
          - path: services/api
            budget: 600
          - path: services/web
            budget: 900
    steps:
      # ... checkout + install as above ...
      - run: tokopt audit ${{ matrix.path }}
      - run: tokopt report ${{ matrix.path }} --threshold ${{ matrix.budget }}
```

### Multiple gates (always-on AND conditional)

Today, `report --threshold` only gates the **always-on** total — that's
the cost paid on every Copilot call, so it's the right primary lever.
For tighter gating across other layers, parse the JSON form yourself:

```yaml
      - name: Custom multi-layer gate
        run: |
          tokopt audit . --format json > audit.json
          ALWAYS=$(jq '.always_on_total' audit.json)
          COND=$(jq '.conditional_total' audit.json)
          [ "$ALWAYS" -le 800 ] || { echo "always-on $ALWAYS > 800"; exit 1; }
          [ "$COND"   -le 1500 ] || { echo "conditional $COND > 1500"; exit 1; }
```

---

## Step 4: Pin the tokopt version

The example installs with `--version v0.1.0` — keep it that way.
Tracking `HEAD` in CI means a tokopt release can change your gate's
verdict overnight without a corresponding PR.

When you upgrade, do it in a **dedicated PR** that only bumps the
version. That way, if a new detector severity or scoring change shifts
the always-on total, the diff that caused it is obvious.

---

## Troubleshooting

### `tokopt: command not found` in a later step

The install script's `PATH` mutation only takes effect for **subsequent
steps**, via `GITHUB_PATH`. If a step runs in a separate shell session
without that, prepend it explicitly:

```yaml
      - run: |
          export PATH="$HOME/.local/bin:$PATH"
          tokopt audit .
```

Or, more robustly, add the line `echo "$HOME/.local/bin" >> "$GITHUB_PATH"`
once after install — already done in the example above.

### Build hangs on download

The installer queries the GitHub release API. If you hit unauthenticated
rate limits (60 req/hr per IP), it can stall. Pinning a `--version`
avoids the "what's the latest tag?" query.

### Cache misses on every run

The install is fast (~2 s), so caching `~/.local/bin/tokopt` between
runs is rarely worth the complexity. If you really want to:

```yaml
      - uses: actions/cache@v4
        with:
          path: ~/.local/bin/tokopt
          key: tokopt-v0.1.0-${{ runner.os }}
```

Skip the install step when the cache hits.

### The gate fired on a PR that didn't touch any prompt files

`tokopt report` runs on the **whole** always-on tree of the PR head, not
on the diff. If a previous merge pushed you over budget and you only
noticed on this PR, the right fix is a separate PR that lowers the
always-on tax — not raising the threshold to paper over it.

---

## What to read next

- [../use-cases/ci-budget-gating.md](../use-cases/ci-budget-gating.md) — the use-case writeup behind this recipe
- [../use-cases/pr-review-with-tokopt.md](../use-cases/pr-review-with-tokopt.md) — using `tokopt` output during human review
- [vscode-tasks.md](vscode-tasks.md) — the same commands locally, before the PR is opened
- [copilot-skills-and-agent.md](copilot-skills-and-agent.md) — get the same numbers via Copilot Chat
