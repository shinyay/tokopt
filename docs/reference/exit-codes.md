# Exit codes

`tokopt` uses a small, stable set of exit codes so CI gates and shell
scripts can react without parsing output. This page is the canonical
matrix.

## The principle

Exit codes communicate **machine-readable intent**. Output may change
between releases, but the meaning of each code is part of the public
contract:

- `0` — the tool ran and the result is acceptable.
- `1` — validation failed or the tool could not complete an operation.
- `2` — a **policy or safety boundary** refused the requested outcome,
  such as an exceeded budget, unsafe file mutation, or corrupted Rewind data.

Keep `1` and `2` separate in CI: `1` should usually retry or alert an
on-call human; `2` should fail the build and ping the author.

## Universal codes

| Code | Meaning                | Triggered by |
|-----:|------------------------|--------------|
| `0`  | Success                | Normal completion. Includes "no findings" and "findings present but no gate set". |
| `1`  | Validation/runtime failure | I/O failures, parse errors, invalid flag values, and missing required arguments. Message printed to stderr with `error:` prefix. |
| `2`  | Policy/safety refusal  | Budget exceeded, unsafe destructive apply, unavailable TTY for confirmation, detected file race/symlink, or corrupted Rewind content. |

## Per-command exit-code matrix

| Command   | Can exit `0` | Can exit `1` | Can exit `2` | Notes |
|-----------|:---:|:---:|:---:|-------|
| `audit`   | ✅  | ✅  | ❌  | No gating flag. Audit reports the tax; budget enforcement lives in `report`. |
| `anatomy` | ✅  | ✅  | ❌  | `1` covers unknown keys in `--json`, missing files, parse errors. |
| `count`   | ✅  | ✅  | ❌  | The smallest primitive — never gates. |
| `detect`  | ✅  | ✅  | ❌  | **Always exits `0` on success, regardless of severity** — including `critical` findings. Detection is informational. Gate with `report --threshold` instead. |
| `report`  | ✅  | ✅  | ✅  | `2` when `--threshold > 0` and the always-on total exceeds it. |
| `tail`    | ✅  | ✅  | ❌  | `1` covers missing `--input`, missing column, malformed records. |
| `slim`    | ✅  | ✅  | ✅  | `2` for destructive-flow safety refusals, including JSON/YAML apply without `--allow-format-change`; dry-run and user-declined confirmation return `0`. |
| `rewind`  | ✅  | ✅  | ✅  | `2` for integrity corruption; invalid hashes, missing stores/blobs, and other runtime failures return `1`. |
| `chat-compact` | ✅ | ✅ | ✅ | Apply mode reuses the slim mutation safety ladder. |
| `models`  | ✅  | ✅  | ❌  | Malformed external rate cards return `1`. |
| `version` / `completion` / `help` | ✅ | ✅ | ❌ | Invalid usage or output failures return `1`. |

> [!IMPORTANT]
> `tokopt detect` will not break your build even on `critical` findings.
> If you want CI to fail on token-budget regressions, you must run
> `tokopt report --threshold N`. This is intentional: detection is
> noisy by design (it flags low-confidence quality issues too), so
> gating is delegated to `report`'s measured always-on total.

## CI gating recipes

### Read the exit code in shell

```bash
tokopt report . --threshold 800
echo "exit=$?"
```

Inspect `$?` immediately — any subsequent command (including `echo`)
overwrites it.

### Branch on the three codes

```bash
tokopt report . --threshold 800
case $? in
  0) echo "✓ within budget" ;;
  1) echo "✗ tokopt failed to run"; exit 1 ;;
  2) echo "✗ always-on tax exceeded budget"; exit 1 ;;
esac
```

### GitHub Actions

A non-zero exit naturally fails the step:

```yaml
- name: Token budget gate
  run: tokopt report . --threshold 800
```

To distinguish operational errors from budget violations, capture the
code:

```yaml
- name: Token budget gate
  id: gate
  run: |
    set +e
    tokopt report . --threshold 800
    echo "code=$?" >> "$GITHUB_OUTPUT"
- name: Annotate budget violations
  if: steps.gate.outputs.code == '2'
  run: echo "::error::Always-on token budget exceeded"
```

### Chain commands with `&&`

`&&` only runs the next command if the previous exited `0`, so it
honours both `1` and `2`:

```bash
tokopt audit . && tokopt report . --threshold 800
```

## Common pitfalls

- **Using `audit` for CI gates.** `audit` always exits `0` on success
  — it has no `--threshold`. Use [`report --threshold`](../commands/report.md).
- **Confusing "no findings" with "passed budget".** `detect` returns
  `0` whether or not it found anything. A green `detect` does **not**
  mean you're under budget; only `report --threshold` checks that.
- **Suppressing exit codes by piping.** A pipeline's exit code is the
  exit code of the **last** command. `tokopt report ... | tee out.txt`
  will return `tee`'s exit code, not tokopt's. In bash, set
  `set -o pipefail` (or read `${PIPESTATUS[0]}`) to preserve upstream
  failures.
- **Treating `1` as a budget violation.** `1` means "tokopt couldn't
  run" (file missing, parse error). Don't auto-merge or auto-close
  PRs based on `1` — investigate first.
- **Off-by-one with `--threshold`.** The check is strict `>`. A
  threshold of `800` accepts `800` exactly and rejects `801`. If you
  want `≤ 800` to fail, set `--threshold 799`.

## See also

- [`cli-reference.md`](cli-reference.md) — per-command flag tables.
- [`../commands/report.md`](../commands/report.md) — full `report` documentation.
- [`output-formats.md`](output-formats.md) — what stdout looks like for each code path.
