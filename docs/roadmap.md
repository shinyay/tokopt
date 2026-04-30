# Roadmap

Where tokopt is going, what's intentionally out of scope, and how to
influence the direction.

---

## Status

**v0.1.0** is the first public release. It is stable enough for CI gating
today — the [`report --threshold`](commands/report.md) contract and the
[exit-code matrix](reference/exit-codes.md) are part of the public surface
and won't change without a deprecation note. Output **schemas** (the
shape of `--format json`) may still evolve through `v1.0`; pin the tokopt
version in CI if you depend on field names.

## The principle

tokopt is **intentionally small**. It does six things:
[audit](commands/audit.md), [anatomy](commands/anatomy.md),
[detect](commands/detect.md), [tail](commands/tail.md),
[report](commands/report.md), [count](commands/count.md). The roadmap
reflects **depth** — better measurement, sharper detectors, more reliable
distribution — over **breadth** (more commands, more surface area).

When in doubt, the question we ask is: *"does this make the existing
measurement more honest, or does it just add features?"* If the answer
is the second one, it doesn't ship.

---

## Near-term (next few minor releases)

- **Output schema stability.** Lock in the JSON schemas for `audit`,
  `anatomy`, `detect`, `tail`, and `report` so they're safe to consume
  from third-party tooling without pinning. Goal: no breaking JSON
  changes between v1.0 and v2.0.
- **More detectors.** The current
  [10 detectors](commands/detect.md#detectors) cover the patterns we
  saw in the wild repeatedly. Community feature requests will drive the
  next batch — see [`use_case.yml`](https://github.com/shinyay/tokopt/issues/new/choose)
  to suggest one.
- **Better cross-platform coverage.**
  - Code-signed macOS binary (resolves the Gatekeeper symptom in
    [troubleshooting.md](troubleshooting.md#symptom-macos-gatekeeper-blocks-the-binary-cannot-be-opened-because-the-developer-cannot-be-verified)).
  - Windows arm64 build (currently the missing cell in the
    [platform matrix](installation.md#supported-platforms)).
  - Authenticode signature on the Windows binary.
- **Cache / perf improvements** for very large monorepos. Today the
  scanner re-tokenizes everything on each run; for repos with thousands
  of always-on files a content-hash cache becomes worthwhile.
- **Optional `tokopt watch` mode** that re-runs `audit` on file change.
  Targeted at the editing loop, not at CI.

---

## Medium-term

These are likely-but-not-committed. They depend on demand and on whether
they fit the principle above.

- **`tokopt diff <ref>`** — show the always-on tax delta between two git
  refs. Useful for "this PR added 320 tokens to the always-on tax,
  here's what" annotations.
- **`tokopt budget show / set`** — manage `--threshold` values in a
  config file rather than scattering them across CI yaml. Would
  introduce the project's first config file (currently there is none).
- **Cross-encoding comparison output** — run `audit` with both
  `o200k_base` and `cl100k_base` and emit a single side-by-side report.
  Useful for teams shipping to multiple model families.
- **Plugin / detector SDK.** A way for users to write custom
  anti-pattern detectors against their own house rules without forking
  tokopt. Open question: do we ship this as a Go package, a separate
  binary protocol, or a directory of declarative rule files?

---

## Long-term / open questions

These are real maybes. Listed here for transparency, not as commitments.

- **Source code release.** The tokopt binary repo is currently
  closed-source. The companion source repo at
  [shinyay/getting-started-with-token-optimization](https://github.com/shinyay/getting-started-with-token-optimization)
  is fully open and contains the editorial material, the integrations,
  and the worked examples the tool is built around. Whether to open the
  binary repo too depends on whether community engagement justifies
  running it as a public Go project — that's a real maintenance
  commitment, not a checkbox. See [faq.md](faq.md#q-why-isnt-the-source-code-public).
- **Homebrew formula / official package-manager presence** (apt, dnf,
  scoop, winget). Today the only supported install path is
  [`install.sh`](installation.md#install-via-the-script-recommended)
  or manual download. Package-manager presence is mostly distribution
  toil; we'll do it when there's demand and the binary is signed on the
  relevant platforms.
- **VS Code extension** that wraps tokopt natively. Currently the
  IDE story is the
  [Copilot Chat skills + `token-doctor` agent](integrations/copilot-skills-and-agent.md)
  and the [VS Code Tasks integration](integrations/vscode-tasks.md). A
  native extension would add a panel UI, but that's a significant scope
  jump and would have to fight the "no UI" principle below.
- **First-class non-OpenAI tokenizer support** for Claude, Gemini, and
  Llama. Today their counts are
  [directional approximations](reference/encodings.md#choosing-an-encoding).
  Fixing this depends on whether each vendor ships a usable local
  tokenizer that can be linked into a Go binary without CGo.

---

## What we will *not* add

These are deliberate. They are not "we haven't gotten to them yet" —
they are **out of scope by design**.

- **A SaaS dashboard.** tokopt is local-first. If you need
  multi-tenant rollups or hosted alerting, use a commercial tool.
- **A web UI.** CLI-first by design. The chat skills + the
  `token-doctor` agent are the GUI story.
- **Telemetry of any kind.** No usage pings. No update check. No
  analytics. The binary makes zero outbound network calls. See
  [faq.md](faq.md#q-does-tokopt-phone-home--send-data-anywhere).
- **Auto-fix mode.** tokopt will never edit your files for you.
  Detectors flag; humans decide what to delete. The whole point of the
  tool is that the cuts are deliberate.

---

## How to influence the roadmap

- **Open a feature request:**
  [`feature_request.yml`](https://github.com/shinyay/tokopt/issues/new?template=feature_request.yml).
- **Share a use case:**
  [`use_case.yml`](https://github.com/shinyay/tokopt/issues/new?template=use_case.yml)
  — these are weighted heavily because they ground feature decisions in
  real workflows.
- **Vote on existing issues** with 👍 reactions. The roadmap above is
  re-prioritised based on what's already getting attention.

If your need is in "what we will not add", consider whether it can be
served by an integration around tokopt rather than inside it. The
`--format json` output is designed to be consumed by other tools.
