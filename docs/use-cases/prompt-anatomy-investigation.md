# Prompt anatomy investigation

How to figure out where the tokens in a single LLM call are actually
going — and whether the *user's question* is even a meaningful share
of the prompt.

---

## Problem

You sent a one-sentence question to a chat tool and the call billed
4,800 tokens. You want to know which segment of the assembled prompt
ate the budget — system prompt? always-on instructions? tool catalog?
retrieved context? — so you can attack the right thing.

## Who this is for

- Application engineers debugging high per-call token cost on a
  Copilot/Claude/OpenAI-backed feature.
- Prompt designers tuning a RAG pipeline who suspect retrieved chunks
  are crowding out the user's intent.
- Agent authors instrumenting their own runtime to see what fraction
  of input is overhead vs. signal.

## What you'll need

- `tokopt` v0.1.0 or later (`tokopt --version`).
- The actual content of each segment of the prompt — not summaries,
  not estimates. See **Step 1** for how to capture each.
- A scratch directory to hold the segment files (a `prompt/` folder
  in your project is fine).

---

## Steps

### 1. Capture each segment to its own file

`tokopt anatomy` decomposes a prompt into **seven canonical segments**:
`system`, `always-on`, `tools`, `history`, `retrieved`, `user`,
`reasoning`. You only have to provide the ones that exist for your
call — missing segments are reported as `0` and excluded from
warnings. Reference: [`../commands/anatomy.md`](../commands/anatomy.md).

Capture each segment as a plain-text file. The mapping for a typical
Copilot-style call:

| Segment      | What goes in the file                                                                 |
|--------------|---------------------------------------------------------------------------------------|
| `system`     | The model's system prompt (the host's, e.g., "You are GitHub Copilot…").              |
| `always-on`  | `cat .github/copilot-instructions.md AGENTS.md` (whichever apply for your repo).      |
| `tools`      | The tool / function catalog the host injected. Often a JSON-array string.             |
| `history`    | All prior turns of the conversation, concatenated. Often the largest segment.         |
| `retrieved`  | RAG chunks, file reads, search results — anything the host pulled in for this turn.   |
| `user`       | The single message you (or your user) just typed.                                     |
| `reasoning`  | Optional. Chain-of-thought / reasoning tokens, if the model exposes them.             |

Practical capture tips:

- **Always-on**: just `cp` the files.

  ```bash
  mkdir -p prompt
  cat .github/copilot-instructions.md AGENTS.md > prompt/always-on.txt
  ```

- **User**: paste the exact text you sent into a file.

  ```bash
  printf '%s\n' "Refactor handleClick to be async" > prompt/user.txt
  ```

- **History**: dump the prior conversation. If you have a JSON
  transcript, `jq -r '.messages[] | "\(.role): \(.content)"'` works.
  Concatenate everything before the current user turn into one file.

- **Tools / retrieved / reasoning**: only available if your host
  exposes them. Many do via debug logs or API responses (e.g.,
  OpenAI's `usage.completion_tokens_details.reasoning_tokens` or the
  full request body in dev mode).

> [!TIP]
> If you can't capture a segment, **don't fake it**. Anatomy will
> simply report it as `0` and skip warnings that depend on it. A
> partial picture from real data is better than a complete picture
> from estimates.

### 2. Run anatomy across what you captured

```bash
tokopt anatomy \
  --system    prompt/system.txt \
  --always-on prompt/always-on.txt \
  --tools     prompt/tools.json \
  --history   prompt/history.txt \
  --retrieved prompt/retrieved.txt \
  --user      prompt/user.txt
```

Sample output (real numbers from a debugging session):

```text
tokopt anatomy  encoding=o200k_base  total input=4812 tokens

SEGMENT    TOKENS  BYTES  % OF INPUT
system        180    721    3.7%
always-on    2532  11214   52.6%
tools         412   1830    8.6%
history      1180   5022   24.5%
retrieved     494   2210   10.3%
user           14     58    0.3%
reasoning       0      0    0.0%

warnings:
  • user message is < 1% of input — your intent is a rounding error
  • system+always-on+tools is > 50% of input — most of every call is overhead
```

The percentages are computed against the **sum of provided segments**,
not against any external context-window size. (For window-relative
view, use `tokopt audit --reference-window N`.)

### 3. Read the % column

Sort the segments by percentage. The largest one is your investigation
target. In the sample above, that's `always-on` at 52.6%.

Two warnings in the output give you the *interpretation*:

- **`user message is < 1% of input`** — you're asking the model to
  infer intent from almost no signal. The model has 14 tokens of
  question and 4,798 tokens of "context" to weigh it against.
- **`system+always-on+tools is > 50% of input`** — the structural
  overhead alone is more than half the call. Even before history and
  retrieved chunks join, you're already past the halfway mark.

Both warnings point at the same conclusion: the user-signal share is
broken. See the
[two-levers framing](../concepts/three-layer-model.md) — fix the
always-on bucket *and* write more specific user messages, not one or
the other.

### 4. Drill into the largest segment

Once you know the offender (e.g., `always-on`), re-run anatomy with
**only that segment** to confirm the number:

```bash
tokopt anatomy --always-on prompt/always-on.txt
```

```text
tokopt anatomy  encoding=o200k_base  total input=2532 tokens

SEGMENT    TOKENS  BYTES  % OF INPUT
always-on  2532   11214  100.0%
...
```

This is the same as `tokopt count prompt/always-on.txt` — confirmation
that no surprise byte-handling is in play. From here, switch to
[`tokopt audit`](../commands/audit.md) and
[`tokopt detect`](../commands/detect.md) on the source repo to find
*which file* in the always-on bucket is the offender:

```bash
tokopt detect .
```

If the offender is `history`, the fix is in your application
(truncate or summarise old turns). If it's `retrieved`, the fix is in
your RAG pipeline (smaller chunks, better re-ranking, top-K reduction).
If it's `tools`, see the `mcp-overload` and `verbose-tool-descriptions`
detectors in [`../commands/detect.md`](../commands/detect.md#detectors).

### 5. Compare against a healthy distribution

There is no universal "correct" shape, but a useful rule of thumb:

| Segment      | Healthy share (rough) | Red flag                                       |
|--------------|-----------------------|------------------------------------------------|
| `user`       | > 1%, ideally > 5%    | < 1% means the model is guessing your intent.  |
| `system+always-on+tools` | < 50%     | > 50% means most of the call is overhead.       |
| `history`    | < 40%                 | > 40% means consider summarising old turns.     |
| `reasoning`  | < 20%                 | > 20% means audit whether you need it on.       |

These exact thresholds are the ones `tokopt anatomy` warns on — see
[`../commands/anatomy.md`](../commands/anatomy.md#warnings) for the
full table. They are heuristics, not laws.

---

## Expected outcome

A single sentence you can put in a bug report or a Slack thread:

> "Our user message is 0.3% of total input (14 / 4,812 tokens). The
> always-on bucket is 52.6%. Even before history loads, structural
> overhead is the majority of every call."

That sentence is actionable. It points at the always-on bucket as the
first thing to attack, and it gives you a number to beat after you
make changes.

---

## Variations

### Agent-mode anatomy (include tools)

If your agent calls MCP tools, the `tools` segment is likely large and
under-noticed. Capture the tool catalog the host actually injected
(often visible in debug logs or via your MCP host's `--list-tools`
flag), put it in `prompt/tools.json`, and pass `--tools`:

```bash
tokopt anatomy --tools prompt/tools.json --always-on prompt/always-on.txt
```

If `tools` exceeds 1,000 tokens, run `tokopt detect .` to surface the
`mcp-overload` and `verbose-tool-descriptions` findings — both are
measured detectors with concrete savings.

### RAG-heavy app: focus on `--retrieved`

For RAG, `retrieved` is usually the dominant segment. Capture one
turn's worth of chunks:

```bash
tokopt anatomy --retrieved prompt/retrieved.txt --user prompt/user.txt
```

If `retrieved` is > 60% of input on a typical query, the fix is
upstream of tokopt — re-ranking, top-K reduction, chunk size — not in
the prompt. tokopt's job here is to *prove* the segment is the cause,
not to fix it.

### Reasoning models: capture `--reasoning`

Models that expose reasoning tokens (e.g., OpenAI's `o*`-series, some
Anthropic settings) bill those tokens at output rate. Capture the
reasoning trace from the API response and pass `--reasoning`:

```bash
tokopt anatomy --reasoning prompt/reasoning.txt --user prompt/user.txt
```

If `reasoning` > 20% of input, anatomy will warn. Confirm the depth
is needed for the task — for many calls, reasoning can be made opt-in
per request, not always-on.

---

## What to read next

- [`auditing-a-template-repo.md`](auditing-a-template-repo.md) — once
  anatomy fingers `always-on` as the offender, this recipe is the
  next step.
- [`monitoring-token-spend.md`](monitoring-token-spend.md) — anatomy
  is the per-call view; `tail` is the per-day view.
- [`../commands/anatomy.md`](../commands/anatomy.md) — full reference
  for flags, warnings, and JSON schema.
- [`../commands/count.md`](../commands/count.md) — the single-file
  primitive anatomy is built on.
- [`../concepts/three-layer-model.md`](../concepts/three-layer-model.md)
  — the static-config view that explains *why* the always-on segment
  matters disproportionately.
