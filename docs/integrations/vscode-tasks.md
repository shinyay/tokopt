# VS Code Tasks

## Problem

You want to run `tokopt` from inside VS Code — auditing the repo, scanning
for anti-patterns, gating against a budget — without typing the full
command into a terminal every time.

VS Code's built-in **Tasks** system is the right primitive: it binds a
shell command to a label, runs it in a dedicated terminal panel, and can
be invoked from a menu (or a keybinding).

## Who this is for

VS Code users who already have `tokopt` on their `PATH` (see
[../installation.md](../installation.md)) and want one-keypress access to
the most common commands while editing.

If you want `tokopt` available inside **Copilot Chat** as well, see
[copilot-skills-and-agent.md](copilot-skills-and-agent.md). If you want
CI gating, see [github-actions.md](github-actions.md).

---

## Step 1: Copy the example tasks file

The repo ships a verified `tasks.json` at
[`examples/tasks.json`](https://github.com/shinyay/tokopt/blob/main/examples/tasks.json).
Drop it at `.vscode/tasks.json` in the repo you want to instrument:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "tokopt: audit current repo",
      "type": "shell",
      "command": "tokopt",
      "args": ["audit", "${workspaceFolder}"],
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "clear": true
      }
    },
    {
      "label": "tokopt: detect anti-patterns",
      "type": "shell",
      "command": "tokopt",
      "args": ["detect", "${workspaceFolder}"],
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "clear": true
      }
    },
    {
      "label": "tokopt: report (CI gate)",
      "type": "shell",
      "command": "tokopt",
      "args": ["report", "${workspaceFolder}", "--threshold", "800"],
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "clear": true
      }
    },
    {
      "label": "tokopt: anatomy of selection",
      "type": "shell",
      "command": "tokopt",
      "args": [
        "anatomy",
        "--always-on", "${workspaceFolder}/.github/copilot-instructions.md",
        "--user", "${file}"
      ],
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "dedicated",
        "clear": true
      }
    }
  ]
}
```

The four tasks cover the everyday loop:

- **audit** — total always-on / conditional / on-demand cost
- **detect** — anti-pattern findings (always exits 0)
- **report (CI gate)** — same as audit + detect, but with a **threshold**
  that exits 2 on violation (mirror this exact value in CI)
- **anatomy of selection** — splits the always-on file plus the currently
  open editor file (`${file}`) into its 7 segments

### Where it goes

| Layout | Path |
|---|---|
| Single-folder workspace | `.vscode/tasks.json` (in the repo root) |
| Multi-root workspace | `.vscode/tasks.json` per folder, **or** the `tasks` key inside the `.code-workspace` file |

### Merging with existing tasks

If `.vscode/tasks.json` already exists, don't replace it — append the
four task objects to the existing `tasks` array. The `label` strings are
unique, so they won't collide with anything you have.

---

## Step 2: Run a task

1. `Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Linux/Windows)
2. Type **`Tasks: Run Task`** and press Enter
3. Pick one of the four `tokopt:` entries

The output appears in the integrated terminal panel (a dedicated one,
because `presentation.panel: "dedicated"` keeps each task's history
separate from any other terminal you have open).

---

## Step 3: Bind to a keybinding (optional)

For repeated audits during a refactor, a keybinding is faster than the
command palette.

1. `Cmd+Shift+P` / `Ctrl+Shift+P` → **`Preferences: Open Keyboard Shortcuts (JSON)`**
2. Add entries like:

```json
[
  {
    "key": "cmd+shift+a",
    "command": "workbench.action.tasks.runTask",
    "args": "tokopt: audit current repo"
  },
  {
    "key": "cmd+shift+d",
    "command": "workbench.action.tasks.runTask",
    "args": "tokopt: detect anti-patterns"
  },
  {
    "key": "cmd+shift+r",
    "command": "workbench.action.tasks.runTask",
    "args": "tokopt: report (CI gate)"
  }
]
```

On Linux/Windows, swap `cmd` for `ctrl`. The `args` value must match the
task's `label` exactly.

---

## Step 4: Read the output

Each task prints the same human-readable output as the CLI. To
interpret it, see:

- [../commands/audit.md](../commands/audit.md) — totals and per-file breakdown
- [../commands/detect.md](../commands/detect.md) — severity levels (info / warn / high / critical)
- [../commands/report.md](../commands/report.md) — exit codes, ranked recommendations
- [../commands/anatomy.md](../commands/anatomy.md) — 7-segment split

---

## Variations

### Multi-root workspaces — scope to one folder

Replace `${workspaceFolder}` with `${workspaceFolder:myrepo}`, where
`myrepo` is the folder name as it appears in the workspace tree. Without
the suffix, VS Code prompts you to pick a folder every run.

### Compound task — audit + detect + report in sequence

Add this to the `tasks` array:

```json
{
  "label": "tokopt: full pass",
  "dependsOrder": "sequence",
  "dependsOn": [
    "tokopt: audit current repo",
    "tokopt: detect anti-patterns",
    "tokopt: report (CI gate)"
  ],
  "problemMatcher": []
}
```

`dependsOrder: "sequence"` ensures `report`'s exit-2 behaviour fires
**after** the audit and detect output is on screen.

### Run on save / pre-commit

Tasks aren't the right primitive for hard gating — they're a
developer-loop convenience. For PR-blocking enforcement, use the
GitHub Actions workflow described in
[../use-cases/ci-budget-gating.md](../use-cases/ci-budget-gating.md)
(and [github-actions.md](github-actions.md) for the install recipe).

---

## Troubleshooting

### `Command 'tokopt' not found`

VS Code's task runner uses your login shell's `PATH`. If `tokopt` works
in a fresh terminal but not in a task, your shell rc file may not be
sourced for non-interactive shells.

Fix: ensure your install location is on `PATH` system-wide. See
[../installation.md](../installation.md#adding-to-path-per-shell) for
the per-shell snippets (`~/.zshrc`, `~/.bashrc`, fish, etc.). After
editing, fully restart VS Code (not just reload the window) so the new
`PATH` is picked up.

### `Permission denied`

The binary lost its executable bit (common after a manual extract).

```bash
chmod +x "$(command -v tokopt)"
```

### The task ran but exited with code 2

That's `report --threshold` doing its job — the always-on tax is over
budget. See [../commands/report.md](../commands/report.md#exit-codes).

---

## What to read next

- [copilot-skills-and-agent.md](copilot-skills-and-agent.md) — reach `tokopt` from Copilot Chat
- [github-actions.md](github-actions.md) — gate every PR on the budget
- [../installation.md](../installation.md) — per-shell `PATH` setup
