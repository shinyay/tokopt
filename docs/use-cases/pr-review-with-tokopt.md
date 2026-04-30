# PR review with tokopt

How to tell, as a reviewer, whether a pull request makes the always-on
token tax worse — without trusting the author's "shouldn't be much"
hand-wave.

---

## Problem

A PR touches `.github/copilot-instructions.md`, `AGENTS.md`, an agent
file, or a skill definition. The diff looks small but markdown is
deceptive: a 12-line "small clarification" can add 800 tokens that
every contributor will pay forever. You want a measured before/after
delta to paste into the PR conversation.

## Who this is for

- Code reviewers covering PRs against repos that ship Copilot config.
- Maintainers triaging community contributions to a Copilot template.
- Anyone who's been bitten by silent always-on bloat once and is now
  doing it the careful way.

## What you'll need

- `tokopt` v0.1.0 or later locally (`tokopt --version`).
- `git` and `gh` (or the ability to check out arbitrary refs).
- `jq` for the JSON-diff variant (optional but recommended).
- 2–3 minutes per PR.

---

## Steps

### 1. Check out the PR branch locally

```bash
gh pr checkout 1234
```

If you don't use `gh`:

```bash
git fetch origin pull/1234/head:pr-1234
git checkout pr-1234
```

### 2. Take a snapshot of the PR-branch totals

Generate a structured audit and save it next to the repo (use a
project-local scratch dir, e.g., `.tokopt-review/`, not `/tmp`, so
the artefacts don't leak between repos):

```bash
mkdir -p .tokopt-review
tokopt audit . --format json > .tokopt-review/after.json
```

### 3. Switch back to the base branch and snapshot it

```bash
git stash --include-untracked  # park any local changes
git checkout main              # or whatever the PR's base is
tokopt audit . --format json > .tokopt-review/before.json
```

Use a worktree if you don't want to leave your main checkout:

```bash
git worktree add ../repo-base main
( cd ../repo-base && tokopt audit . --format json ) > .tokopt-review/before.json
```

### 4. Diff the two snapshots

The most important field is `always_on_total`. Pull both and subtract:

```bash
before=$(jq '.always_on_total' .tokopt-review/before.json)
after=$(jq  '.always_on_total' .tokopt-review/after.json)
echo "before: $before  after: $after  delta: $((after - before))"
```

Real example output from a review:

```text
before: 2532  after: 3146  delta: +614
```

For a per-file breakdown of *which* always-on file changed, join the
two `files[]` arrays on `path`:

```bash
jq -s '
  (.[0].files | map(select(.scope=="always-on")) | INDEX(.path)) as $b |
  (.[1].files | map(select(.scope=="always-on")) | INDEX(.path)) as $a |
  ($b * $a) | to_entries | map({
    path: .key,
    before: ($b[.key].tokens // 0),
    after:  ($a[.key].tokens // 0),
    delta:  (($a[.key].tokens // 0) - ($b[.key].tokens // 0))
  }) | map(select(.delta != 0))
' .tokopt-review/before.json .tokopt-review/after.json
```

Sample result:

```json
[
  {"path":".github/copilot-instructions.md","before":1116,"after":1730,"delta":614}
]
```

You now know exactly which file grew, by how much, and on which side
of the bucket boundary. The full JSON schema is in
[`../commands/audit.md`](../commands/audit.md#--format-json).

### 5. Pick the right verdict

| Delta on `always_on_total` | Recommended response                                                |
|----------------------------|----------------------------------------------------------------------|
| `0`                        | No always-on impact. Don't comment about tokens.                    |
| `+1` to `+150`             | Acknowledge in the PR but don't block. "+87 always-on tokens, fine." |
| `+150` to `+500`           | Ask for justification. Often the change belongs in a conditional file. |
| `> +500`                   | Block. Suggest moving the content into an on-demand skill or `applyTo` instructions. |
| Negative (a reduction)     | Praise it. Reductions to always-on are pure wins.                    |

These are heuristics, not the law. Adjust to your repo's budget.

### 6. Post findings as a PR comment

The lazy variant: skip the manual diff and post a Markdown report of
the PR branch's current state:

```bash
tokopt report . --format md > .tokopt-review/report.md
gh pr comment 1234 --body-file .tokopt-review/report.md
```

This shows the reviewer the audit + findings + ranked recommendations
as one block. Include the before/after delta from step 4 in your own
comment text.

---

## Expected outcome

You can write a one-liner PR comment like:

> "This PR adds **+614 always-on tokens** to
> `.github/copilot-instructions.md` (1,116 → 1,730). Could the new
> rules go into a scoped instruction file under
> `.github/instructions/` so we only pay for them when relevant?"

Concrete, measured, actionable. No hand-waves about "context bloat".

---

## Variations

### Auto-comment via GitHub Actions

Post the audit delta from CI on every PR that touches a known
always-on file. Concept (full workflow recipe is in
[`ci-budget-gating.md`](ci-budget-gating.md)):

```yaml
- name: Generate report
  run: tokopt report . --format md > tokopt-report.md
- name: Comment on PR
  if: github.event_name == 'pull_request'
  run: gh pr comment "${{ github.event.pull_request.number }}" --body-file tokopt-report.md
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Pair with a path filter so the workflow only runs on PRs that touched
an always-on file:

```yaml
on:
  pull_request:
    paths:
      - '.github/copilot-instructions.md'
      - '**/AGENTS.md'
```

### Block-on-violation mode

Combine the comment with an actual gate:

```bash
tokopt report . --threshold 3000
```

Exit code `2` fails the job (strict `>` — equality passes). See
[`../commands/report.md`](../commands/report.md#exit-codes). Use this
when the comment alone isn't being read.

### Advisory mode (don't gate, just inform)

If your team isn't ready for a hard gate, drop `--threshold` and use
plain `audit`:

```bash
tokopt audit . --format md > .tokopt-review/audit.md
```

`audit` always exits 0. The PR check stays green; the reviewer reads
the comment and decides. This is a good first step before turning on
[`ci-budget-gating.md`](ci-budget-gating.md).

---

## What to read next

- [`ci-budget-gating.md`](ci-budget-gating.md) — automate the manual
  steps above into a blocking CI check.
- [`auditing-a-template-repo.md`](auditing-a-template-repo.md) — the
  full audit recipe this is a quick PR-scoped subset of.
- [`../commands/audit.md`](../commands/audit.md),
  [`../commands/report.md`](../commands/report.md) — full reference
  for the commands used here.
- [`../concepts/three-layer-model.md`](../concepts/three-layer-model.md)
  — why a +614-token always-on delta is worth blocking on but a
  +614-token on-demand delta usually isn't.
