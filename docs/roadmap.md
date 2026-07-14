# Roadmap

Where tokopt is going, what's intentionally out of scope, and how to
influence the direction.

---

## Status

The current CLI release is **v0.18.0**. It supports repository audit,
prompt anatomy, anti-pattern detection, heavy-tail analysis, reporting,
deterministic slim/rewind workflows, chat compaction, model-rate discovery,
version reporting, and shell completion. Output **schemas** may still evolve
before `v1.0`; pin the tokopt version in CI if you depend on field names.

## The principle

tokopt is **intentionally focused**. The roadmap prioritizes **trust, quality
evidence, machine contracts, billing truth, and reliable distribution** over
adding more compression stages or product surface area.

When in doubt, the question we ask is: *"does this make the existing
measurement more honest, or does it just add features?"* If the answer
is the second one, it doesn't ship.

---

## Milestone 1 — Trust restoration

**Completed in v0.18.0.** No new compression stage landed before this gate
closed.

- Required Rewind failures are fatal for the affected file: non-zero exit, no
  downstream stage, no transformed stdout, and no apply. Batch mode records
  the file error and retains its existing best-effort continuation contract.
- Unix Rewind blobs use private modes; get/verify and repeat writes check
  integrity on every platform. Path traversal and symlink escape fail closed.
- JSON/YAML duplicate keys, unsupported structures, and numeric values
  that cannot survive TOON exactly remain unchanged with diagnostics.
- Machine-readable invocations emit one JSON document, including budget
  and slim safety refusals.
- Replacing JSON/YAML source with another media type requires both `--apply` and
  `--allow-format-change`; `--force` cannot bypass it.
- Current versions, compatibility, release procedures, and safety
  terminology remain synchronized across the family.

## Milestone 2 — Quality and contract foundation

- Add an explicit transformation-effect and reversibility model without
  removing existing v1 fields.
- Replace stringly internal context updates with typed deltas and stable
  diagnostic codes.
- Establish deterministic fidelity fixtures and paired downstream quality
  evaluation before enabling any new semantic transform by default.
- Publish a capability-driven machine protocol so consumers never parse
  human output as an API.
- Move the VS Code extension to one typed CLI adapter and eliminate
  unexplained skill/agent drift through generated inventories.

## Milestone 3 — Billing truth and trusted distribution

- Model input, cached input, cache write, output, and long-context rate
  dimensions with provenance and effective dates.
- Separate raw tokens, hypothetical scenarios, actual logged credits, and
  unknown measurement dimensions.
- Add Claude Code repository assets without claiming visibility into
  hidden or dynamically retrieved context.
- Generate compatibility docs from a machine-readable manifest.
- Release from protected source tags with checksums, SBOM, provenance, and
  signatures; broken public releases are withdrawn and replaced, never
  silently re-tagged.

## Deferred v2 candidates

Typed stage APIs, split transformation-policy flags, transactional byte-exact
Rewind manifests, runtime feedback import, and a supported extension model
remain design candidates. They do not start until the three milestones above
and real-user demand justify their migration cost.

---

## What we will *not* add

These are deliberate. They are not "we haven't gotten to them yet" —
they are **out of scope by design**.

- **A SaaS dashboard.** tokopt is local-first. If you need
  multi-tenant rollups or hosted alerting, use a commercial tool.
- **A hosted web UI or control plane.** The CLI and local VS Code extension
  remain the supported interactive surfaces.
- **Telemetry of any kind.** No usage pings. No update check. No
  analytics. The binary makes zero outbound network calls. See
  [faq.md](faq.md#q-does-tokopt-phone-home--send-data-anywhere).
- **Unreviewed auto-fix.** `slim --apply` is explicit and safety-gated;
  tokopt does not silently rewrite files or apply detector suggestions.

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
