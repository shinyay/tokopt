# Troubleshooting

Common symptoms with diagnoses, fixes, and root causes. Symptoms are
grouped by surface (install, command output, CI, encoding, general). For
conceptual questions see [faq.md](faq.md); for the exit-code contract see
[reference/exit-codes.md](reference/exit-codes.md).

---

## Installation problems

### Symptom: `tokopt: command not found` after running `install.sh`

- **Diagnosis:** the binary installed successfully but the install
  directory isn't on the **current shell's** `PATH`. The installer prints
  a `[warn]` line at the end naming the exact directory.
- **Fix (current shell):**

  ```bash
  export PATH="$HOME/.local/bin:$PATH"   # or whatever the installer reported
  tokopt --version
  ```

- **Fix (persistent):** add the same `export` line to your shell rc
  (`~/.bashrc`, `~/.zshrc`) or use `fish_add_path -U` on fish. Per-shell
  snippets are in
  [installation.md#adding-to-path-per-shell](installation.md#adding-to-path-per-shell).
- **Root cause:** `install.sh` writes one file (the binary). It does **not**
  modify your shell rcs — that's a deliberate transparency choice.

### Symptom: `install.sh` fails with "Checksum mismatch" / "SHA256 mismatch"

- **Diagnosis:** the downloaded archive does not match the published
  `SHA256SUMS`. Either the network served a corrupted download, or
  something is interfering with the release artifacts.
- **Fix:** re-run on a clean network. If the failure persists, file a
  **security** issue with the expected and actual hashes the script
  printed.
- **Root cause:** the installer refuses to install a tampered or corrupt
  archive. There is no `--skip-checksum` escape hatch — by design.

### Symptom: `install.sh` says "Unsupported OS" or "Unsupported architecture"

- **Diagnosis:** v0.1.0 ships **5 platform combinations**:
  `linux/amd64`, `linux/arm64`, `darwin/amd64`, `darwin/arm64`,
  `windows/amd64`. Your `uname -s` / `uname -m` doesn't match any of
  them. See the table in
  [installation.md#supported-platforms](installation.md#supported-platforms).
- **Fix:** for unlisted platforms, build from source against the public
  source repo at
  [shinyay/getting-started-with-token-optimization](https://github.com/shinyay/getting-started-with-token-optimization).
  This is currently the only path for unlisted targets. Windows arm64 is
  planned — see [roadmap.md](roadmap.md#near-term-next-few-minor-releases).
- **Root cause:** the installer refuses to guess. Better to fail loudly
  than to install the wrong binary.

### Symptom: macOS Gatekeeper blocks the binary ("cannot be opened because the developer cannot be verified")

- **Diagnosis:** the macOS binaries shipped with v0.1.0 are unsigned.
  We don't have an Apple Developer ID for v0.1.0.
- **Fix (one-liner):**

  ```bash
  xattr -d com.apple.quarantine "$(which tokopt)"
  ```

  Or: System Settings → Privacy & Security → scroll to the blocked
  binary → "Open anyway".
- **Root cause:** code-signing is on the [roadmap](roadmap.md#near-term-next-few-minor-releases)
  but isn't shipped yet. The binary itself is exactly what `SHA256SUMS`
  describes — Gatekeeper is just complaining about the absent signature.

### Symptom: Windows Defender flags the binary

- **Diagnosis:** unsigned Go binary on Windows is a common false-positive
  signal. Defender doesn't recognise the publisher.
- **Fix:** add the binary's directory to Defender's exclusion list, or
  build from source if your environment forbids unsigned binaries.
- **Root cause:** same as macOS Gatekeeper — Authenticode signing is on
  the roadmap, not shipped in v0.1.0.

---

## Command output

### Symptom: `tokopt audit .` reports `0 tokens` but I have files

- **Diagnosis:** `audit` only scans the **always-on Copilot
  configuration** — `.github/copilot-instructions.md`, `AGENTS.md`,
  `.github/instructions/**`, MCP configs, etc. It is not a generic
  "count every token in this repo" command. If your files don't live at
  one of those locations, `audit` ignores them on purpose.
- **Fix:** confirm your files are in the scanned locations
  ([commands/audit.md#files-audited](commands/audit.md#files-audited)).
  To count an arbitrary file, use [`tokopt count <file>`](commands/count.md).
- **Root cause:** `audit`'s job is to measure the **always-on tax**, not
  arbitrary content. Scope is intentional.

### Symptom: `tokopt detect .` doesn't find anti-patterns I expected

- **Diagnosis:** detectors fire on **specific file locations** and
  threshold matches. If your `copilot-instructions.md` lives somewhere
  other than `.github/copilot-instructions.md`, the
  `kitchen-sink-system-prompt` detector won't see it.
- **Fix:** check your file path against the detector triggers in
  [commands/detect.md#detectors](commands/detect.md#detectors). Move the
  file to the canonical location, or open an issue if you think the
  detector should match a broader path.
- **Root cause:** detectors are intentionally precise — vague heuristics
  produce noise, and noisy detectors get ignored.

### Symptom: `tokopt report --threshold 800` exits `0` but I expected failure

- **Diagnosis:** the threshold check uses **strict greater-than** (`>`).
  If `always_on_total == 800`, that passes — only `≥ 801` fails.
- **Fix:** if you want exactly 800 to fail, set `--threshold 799`.
- **Root cause:** documented behaviour. See
  [reference/exit-codes.md](reference/exit-codes.md#common-pitfalls)
  ("off-by-one with `--threshold`") and
  [commands/report.md](commands/report.md).

### Symptom: `tokopt anatomy --format md` works but `--json` outputs nothing useful

- **Diagnosis:** `--json` on `anatomy` is **not** an output toggle. It
  is a **path** to a JSON input file whose keys mirror the per-segment
  flags (`system`, `always_on`, `tools`, ...).
- **Fix:** to get JSON *output*, use the persistent `--format json` flag:

  ```bash
  tokopt anatomy --always-on .github/copilot-instructions.md --format json
  ```

  To use `--json` correctly:

  ```bash
  tokopt anatomy --json prompt-bundle.json --format text
  ```

- **Root cause:** flag overload — `--json` predates the persistent
  `--format` flag and was kept for compatibility. See
  [commands/anatomy.md](commands/anatomy.md) for the full flag table.

---

## CI / GitHub Actions

### Symptom: workflow says `tokopt: command not found` in step N+1

- **Diagnosis:** `install.sh` only updates the **current shell's** `PATH`
  (and only via the `[warn]` hint at the end). GitHub Actions runs each
  `run:` step in a fresh shell, so an `export PATH=...` from step N
  doesn't survive into step N+1.
- **Fix:** persist the install dir for the rest of the job by writing to
  `$GITHUB_PATH` immediately after installing:

  ```yaml
  - run: |
      curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \
        | sh -s -- --prefix "$HOME/.local"
      echo "$HOME/.local/bin" >> "$GITHUB_PATH"
  ```

- **Root cause:** GHA's per-step shell isolation. `$GITHUB_PATH` is the
  intended mechanism.

### Symptom: CI hangs or times out on download

- **Diagnosis:** when `--version` isn't set, `install.sh` queries the
  GitHub Releases API to resolve the `latest` tag. Unauthenticated calls
  to that endpoint are aggressively rate-limited; on a busy CI runner
  shared with other jobs you can hit the limit and hang on retry.
- **Fix:** **pin a version** in CI. Skip the API call entirely:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \
    | sh -s -- --version v0.1.0
  ```

- **Root cause:** `latest`-resolution is convenient for humans, hostile
  to reproducible CI. Pinning is documented in
  [installation.md#pinned-version](installation.md#pinned-version).

### Symptom: PR build always fails on first run after upgrading tokopt

- **Diagnosis:** likely one of two things:
  1. **New detectors** in the upgrade caught findings that the old
     version didn't (this raises severity counts but doesn't change
     `report`'s exit code on its own).
  2. **Tokenizer encoding shift** — if the default encoding changed, or
     `tiktoken-go` was updated, your `always_on_total` may have moved
     past the existing threshold without any code change.
- **Fix:**
  - Re-baseline the threshold: run `tokopt audit . --format json | jq
    .always_on_total` and bump `--threshold` to a deliberate new value.
  - Pin `--encoding` explicitly in CI (don't rely on the default).
  - Pin the tokopt version in CI (`install.sh --version v0.1.0`) so
    upgrades are deliberate.
  - Commit the new threshold as a reviewed change with a one-line note
    explaining what moved.
- **Root cause:** version drift in measurement tools shifts measurements.
  Pinning makes the drift explicit.

---

## Encoding / counts

### Symptom: counts changed between runs without code changes

- **Diagnosis:** the tokopt binary version changed (or
  `--encoding`/default changed) between runs. `o200k_base` and
  `cl100k_base` produce different counts for the same input — typical
  drift is 5–15%.
- **Fix:** pin both the **tokopt version** and the `--encoding` flag in
  CI. Don't rely on the default. See
  [reference/encodings.md](reference/encodings.md#what-changes-if-i-switch-encodings).
- **Root cause:** measurement is only stable if the measuring instrument
  is stable.

### Symptom: `tokopt anatomy` says `always-on = 0` but I have a `copilot-instructions.md`

- **Diagnosis:** `anatomy` does **not** auto-discover files. You must
  pass `--always-on FILE` explicitly. Unlike `audit`, which walks the
  repo, `anatomy` only reads what you point it at.
- **Fix:**

  ```bash
  tokopt anatomy --always-on .github/copilot-instructions.md \
                 --user user-msg.txt --format text
  ```

- **Root cause:** `anatomy` is the **runtime** counterpart of `audit` —
  it measures the assembled prompt you choose to give it, not whatever
  the repo happens to contain.

---

## General

### Symptom: confusing CLI error message ("unknown command", "unknown flag")

- **Diagnosis:** cobra (the CLI library tokopt uses) auto-generates
  these messages. Most often the subcommand or flag is misspelled, or
  you're using a flag from a different command.
- **Fix:**

  ```bash
  tokopt --help              # list commands
  tokopt <cmd> --help        # list flags for that command
  ```

  Cross-check against
  [reference/cli-reference.md](reference/cli-reference.md).
- **Root cause:** cobra's defaults are fine but terse. The full reference
  is more forgiving than the inline error.

### Symptom: I think I found a bug

- **Fix:** open an issue using the bug-report template, with:
  - tokopt version (`tokopt --version`)
  - OS / arch
  - exact command run
  - actual vs expected output
  - minimal reproduction (a small file or repo if relevant)

  Templates: [`bug_report.yml`](https://github.com/shinyay/tokopt/issues/new/choose).

  For runtime behaviour we can't reproduce from the description, the
  reproduction is the difference between "fixed in next release" and
  "wontfix — can't repro".

---

## See also

- [faq.md](faq.md) — conceptual / "why" questions.
- [reference/exit-codes.md](reference/exit-codes.md) — exit-code contract
  and CI patterns.
- [installation.md#troubleshooting-install](installation.md#troubleshooting-install)
  — install-specific symptoms not covered here.
