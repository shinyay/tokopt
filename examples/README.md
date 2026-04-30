# tokopt examples

Runnable demo files for the `tokopt` CLI. Each file is self-contained
and assumes the `tokopt` binary is already on your `$PATH`.

## Files

| File | Purpose |
| --- | --- |
| `always-on.txt` | A fictional always-on Copilot instructions segment used as the `--always-on` input for `anatomy`. |
| `user-message.txt` | A realistic single user turn used as the `--user` input for `anatomy`. |
| `usage-log.jsonl` | A 20-line JSONL token-usage log (field: `tokens`) for `tokopt tail`. |
| `tasks.json` | VS Code tasks that run `tokopt audit`, `detect`, `report`, and `anatomy` with one keypress. Copy into `.vscode/tasks.json`. |
| `github-workflows/token-budget.yml` | GitHub Actions workflow that installs `tokopt` and gates PRs on the always-on token budget. Copy into `.github/workflows/`. |

## Quick demo

Run from the directory that contains `examples/`:

```bash
# Decompose a hypothetical prompt into the seven canonical segments.
tokopt anatomy \
  --always-on examples/always-on.txt \
  --user      examples/user-message.txt

# Heavy-tail percentile analysis of a usage log (JSONL).
tokopt tail --input examples/usage-log.jsonl
```

`tokopt tail` requires the `--input` flag (the path is not positional).
The default token-count field is `tokens`; override with `--column` if
your log uses a different name.
