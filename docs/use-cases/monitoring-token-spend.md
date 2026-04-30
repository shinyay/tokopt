# Monitoring token spend

How to turn day-to-day chat / agent usage into a percentile picture
you can watch week over week — and how to spot the few outlier calls
that drive most of the bill.

---

## Problem

You use Copilot / Claude / some chat tool every day across many
sessions. Sometimes a single call is 7,500 tokens; sometimes it's 800.
You want to know whether your spend is healthy or quietly getting
worse — and which specific calls to investigate when it's worse.

## Who this is for

- Heavy individual users of LLM-backed tools (developers, researchers,
  writers) who want a per-week dashboard for their own usage.
- Small teams sharing a billing account who want to spot per-user
  outliers.
- Platform teams running an internal LLM gateway who want a cheap
  heavy-tail report without standing up Grafana.

## What you'll need

- A way to capture one record per LLM call into a JSONL file (one
  JSON object per line). See **Step 1** for the canonical shape.
- `tokopt` v0.1.0 or later (`tokopt --version`).
- A place to keep the rolling log (a project-local
  `usage/usage.jsonl` is fine; rotate weekly).

---

## Steps

### 1. Get a usage log into the canonical shape

`tokopt tail` reads a JSONL or CSV file with one record per LLM call.
The minimum required field is the token count. The reference shape
(matching `examples/usage-log.jsonl` in the tokopt repo) is:

```jsonl
{"timestamp":"2026-04-29T08:12:04Z","session":"s-001","turn":1,"prompt_tokens":820,"completion_tokens":140,"tokens":960}
{"timestamp":"2026-04-29T08:18:33Z","session":"s-001","turn":2,"prompt_tokens":880,"completion_tokens":210,"tokens":1090}
{"timestamp":"2026-04-29T10:02:44Z","session":"s-003","turn":2,"prompt_tokens":870,"completion_tokens":1850,"tokens":2720}
{"timestamp":"2026-04-29T16:08:44Z","session":"s-008","turn":2,"prompt_tokens":4100,"completion_tokens":3650,"tokens":7750}
```

The required field name is configurable via `--column` (default:
`tokens`). Records missing the column are silently skipped, so it's
fine to mix in heterogeneous events.

If your tool doesn't natively produce a log in this shape, write a
small adapter:

- **Copilot CLI / API responses**: pipe the response JSON through
  `jq -c '{timestamp: now|todate, tokens: .usage.total_tokens, prompt_tokens: .usage.prompt_tokens, completion_tokens: .usage.completion_tokens}'`
  and append to your log file.
- **OpenAI / Anthropic SDK callers**: hook the SDK's
  `usage`/`usage.input_tokens`/`usage.output_tokens` and append a JSON
  line per call.
- **CSV from a billing dashboard**: works directly if it has a
  numeric column; pass `--column total_tokens` (or whatever the
  header is — case-insensitive).

The full input contract is in
[`../commands/tail.md`](../commands/tail.md#input-format).

### 2. Get the percentile picture

```bash
tokopt tail --input usage.jsonl
```

Sample output on the example log shipped with tokopt (200 records):

```text
tokopt tail  source=usage.jsonl  format=jsonl  column=tokens  records=200

  mean: 1387.5  p50: 980  p90: 1420  p95: 2140  p99: 6510  max: 7750
  the top 1% of records account for 18.4% of total tokens

outliers:
  1. 7750 tokens — timestamp=2026-04-29T16:08:44Z session=s-008 turn=2 prompt_tokens=4100 completion_tokens=3650
  2. 5300 tokens — timestamp=2026-04-29T12:22:55Z session=s-005 turn=2 prompt_tokens=3200 completion_tokens=2100
  3. 2720 tokens — timestamp=2026-04-29T10:02:44Z session=s-003 turn=2 prompt_tokens=870  completion_tokens=1850
  4. ...
```

What to read first:

- **`p50` (median)** — the typical call. If `p50` drifts up, your
  default workload got more expensive.
- **`p99`** — the heavy-tail edge. A handful of calls that
  individually dwarf everything else.
- **`top 1% share`** — concentration. If 1% of calls are >30% of
  total spend, fixing the few outliers beats trimming the median.
- **`outliers:`** — the actual records, with their original payload
  preserved. Now you can identify *which session* spent the tokens.

The hint line `the top 1% of records account for >30% of total tokens
— investigate the outliers above` is emitted by `tail` only when
`records ≥ 100` and the share is >30%. See
[`../commands/tail.md`](../commands/tail.md#output) for the exact
trigger.

### 3. Establish a baseline

Run `tail` once on a representative week's worth of usage and write
the numbers down somewhere durable. Example baseline for the workload
above:

| Metric           | Baseline | Notes                                   |
|------------------|---------:|-----------------------------------------|
| `count`          |      200 | calls/week                              |
| `p50`            |      980 | "typical chat turn"                     |
| `p95`            |    2,140 | "moderately heavy turn"                 |
| `p99`            |    6,510 | "the agent ran a 5-tool plan"           |
| `top_share_pct`  |    18.4% | concentration; below the 30% hint line  |

These five numbers are your scorecard. Anything outside them next week
is worth a look.

### 4. Re-run weekly and watch for drift

A simple weekly check:

```bash
tokopt tail --input usage-week-of-2026-05-06.jsonl --format json > tail.json
jq '{p50, p95, p99, top_share_pct}' tail.json
```

The two failure modes to look for:

- **`p99` climbing** — your worst calls are getting worse. Often a
  single agent or pipeline started doing more per invocation. Drill
  into the `top_records` (next step).
- **`top_share_pct` growing** — even if `p50` is flat, more of the
  bill is concentrated in the long tail. Same fix path: investigate
  outliers.

### 5. Investigate the top-N records

Bump `--top` to surface more outliers and pull their raw records:

```bash
tokopt tail --input usage.jsonl --top 20 --format json | \
  jq '.top_records[] | {tokens, raw}'
```

The `raw` object is whatever you logged — `session`, `turn`,
`prompt_tokens`, `completion_tokens`, plus any custom fields you added.
This is where you cross-reference back into your application:

- Group outliers by `session`. Are they all the same long-running
  agent thread? → truncate or summarise history (see
  [`prompt-anatomy-investigation.md`](prompt-anatomy-investigation.md)).
- Compare `prompt_tokens` vs `completion_tokens`. A 4,100 / 3,650
  split (the s-008 outlier above) means *both* sides were huge —
  often a "summarise this giant document" call that should have been
  chunked.
- Look for repeated timestamps within seconds. A retry storm.

---

## Expected outcome

A short weekly note you can keep next to the log:

> "Week of 2026-05-06: 218 calls. p50=995 (was 980), p95=2,210 (was
> 2,140), p99=6,840 (was 6,510), top-1% share=19.1%. Stable. Top
> outlier was session s-042 turn 4 at 7,420 tokens — same agent that
> blew up last week, ticket already filed."

The value is the *consistency*: you'll spot a real regression — say,
`p99` jumping to 12,000 — long before it shows up on the bill.

---

## Variations

### Daily cron + Slack post

Run nightly, post the summary to a channel:

```bash
#!/usr/bin/env bash
tokopt tail --input "usage/$(date +%F).jsonl" --format md > tail.md
curl -fsSL -X POST "$SLACK_WEBHOOK" \
  -H 'content-type: application/json' \
  --data "$(jq -Rs '{text: .}' < tail.md)"
```

A 5-line summary every morning beats a quarterly bill surprise.

### Per-project / per-client splits

If you bill to multiple clients or have multiple projects sharing one
account, log a `project` field per call, then split before tailing:

```bash
for proj in $(jq -r '.project' usage.jsonl | sort -u); do
  echo "== $proj =="
  jq -c "select(.project == \"$proj\")" usage.jsonl | \
    tokopt tail --input - | head -3
done
```

`tail` reads stdin as JSONL when `--input -` is passed.

### Heavy-tail hunting

When `top_share_pct > 60%`, the percentile metrics are misleading on
their own — a few outliers dominate to the point that `p50` is almost
irrelevant. Switch focus entirely to `top_records`:

```bash
tokopt tail --input usage.jsonl --top 50 --format json | \
  jq '.top_records | sort_by(-.tokens) | .[].raw'
```

Read each one. Fix or rate-limit the source. Re-run; you should see
`top_share_pct` drop sharply once the worst offender is gone.

---

## What to read next

- [`prompt-anatomy-investigation.md`](prompt-anatomy-investigation.md)
  — once `tail` names a specific outlier call, anatomy tells you
  *which segment* of that call was huge.
- [`auditing-a-template-repo.md`](auditing-a-template-repo.md) — if
  your `p50` is high because every call carries a fat always-on
  bucket, the static-config audit is the right next step.
- [`../commands/tail.md`](../commands/tail.md) — full reference
  (input formats, percentiles, JSON schema).
- [`../commands/count.md`](../commands/count.md) — for ad-hoc spot
  checks on a single payload referenced by a top-N record.
- [`../concepts/three-layer-model.md`](../concepts/three-layer-model.md)
  — runtime spend is the consequence of static-config choices; the
  model explains *why* the floor is so hard to escape.
