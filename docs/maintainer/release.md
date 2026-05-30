# Cutting a tokopt release

This runbook walks a maintainer through cutting a `tokopt` release end-to-end:
from a tagged commit in the **source repo** ([shinyay/getting-started-with-token-optimization](https://github.com/shinyay/getting-started-with-token-optimization))
through built archives, a published GitHub release in the **binary repo**
([shinyay/tokopt](https://github.com/shinyay/tokopt)), and a verified
`scripts/install.sh` install on a clean machine.

It is maintainer-facing — Go, the `gh` CLI, and POSIX shell competence are
assumed.

---

## Prerequisites

- **Go 1.22+** on the build machine (`go version`).
- **`gh` CLI** authenticated against the binary repo
  (`gh auth status` — must show `shinyay/tokopt` access with `repo` and
  `write:packages` scopes; `gh auth refresh -s repo` if missing).
- Local clones of **both** repositories, on a known-good commit / branch:
  - Source repo: `git clone https://github.com/shinyay/getting-started-with-token-optimization.git`
    — Go source lives under `tools/tokopt/`.
  - Binary repo (this one): `git clone https://github.com/shinyay/tokopt.git`
    — archives, installer, and docs live here.
- `tar`, `zip`, `sha256sum` (or `shasum -a 256` on macOS), `python3`
  (for the local smoke-test HTTP server).
- (Optional) A GPG key configured with `git config user.signingkey`, for
  signed tags (`git tag -s`).

---

## Release lifecycle

```text
Source repo                              Binary repo (this)
(getting-started-…)                      (tokopt)
-------------------                      ------------------
1. PRs merged to main
2. CHANGELOG.md updated
3. git tag vX.Y.Z         ─────────►
                                         4. Build 5 binaries (cross-compile)
                                         5. Stage into dist/
                                         6. Regenerate SHA256SUMS
                                         7. Smoke-test install.sh locally
                                         8. Mirror CHANGELOG entry
                                         9. git tag + push, gh release create
                                        10. Smoke-test install.sh from live URL
                                        11. Verify `tokopt --version`
```

---

## Step 1 — Confirm the source repo is release-ready

In the **source repo** clone:

```bash
cd <source-repo>
git checkout main
git pull --ff-only

# Tests must be green.
go test ./...

# Verify the version-flag wiring still exists.
grep -n 'var version' tools/tokopt/cmd/tokopt/main.go
# Expected: var version = "dev"
```

The CLI exposes `--version` because `cmd/tokopt/main.go` has:

```go
var version = "dev"

root := &cobra.Command{
    Use:     "tokopt",
    Version: version,
    ...
}
```

That `version` symbol is what the build recipe overrides via
`-ldflags "-X main.version=vX.Y.Z"`. Confirm the source repo's
`CHANGELOG.md` already has an entry for the version you are about to cut.

---

## Step 2 — Tag the source repo

```bash
cd <source-repo>
VERSION=0.1.0   # no leading 'v'; we add it below

git tag -s "v${VERSION}" -m "Release v${VERSION}"
git push origin "v${VERSION}"
```

Conventions:

- **GA**: `vX.Y.Z` (e.g. `v0.1.0`, `v1.2.0`).
- **Release candidate**: `vX.Y.Z-rc.N` (e.g. `v0.2.0-rc.1`).
- **Pre-release / preview**: `vX.Y.Z-pre.N` (rare; prefer `-rc`).
- Tag the commit you intend to ship; do **not** retag.

Drop `-s` if you do not have a GPG key configured. Signed tags are preferred
because the binary release notes link back to this tag as provenance.

---

## Step 3 — Build all 5 binaries

We ship 5 platforms:

| OS      | Arch  | Archive format |
|---------|-------|----------------|
| linux   | amd64 | tar.gz         |
| linux   | arm64 | tar.gz         |
| darwin  | amd64 | tar.gz         |
| darwin  | arm64 | tar.gz         |
| windows | amd64 | zip            |

Run this from the **source repo** root. It writes archives into the
**binary repo's** `dist/` directory.

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION=0.1.0                                    # no leading 'v'
SRC_DIR="$(pwd)/tools/tokopt"                    # where go.mod lives
BIN_REPO="$HOME/work/github/tokopt"              # absolute path to this repo
DIST="${BIN_REPO}/dist"

rm -rf "$DIST"
mkdir -p "$DIST"

# os|arch|ext|archive
PLATFORMS=(
  "linux|amd64||tar.gz"
  "linux|arm64||tar.gz"
  "darwin|amd64||tar.gz"
  "darwin|arm64||tar.gz"
  "windows|amd64|.exe|zip"
)

cd "$SRC_DIR"

for entry in "${PLATFORMS[@]}"; do
  IFS='|' read -r os arch ext archive <<<"$entry"

  stage="$(mktemp -d)"
  out="${stage}/tokopt${ext}"

  echo ">>> building ${os}/${arch}"
  GOOS="$os" GOARCH="$arch" CGO_ENABLED=0 \
    go build \
      -ldflags "-s -w -X main.version=v${VERSION}" \
      -trimpath \
      -o "$out" \
      ./cmd/tokopt

  base="tokopt-v${VERSION}-${os}-${arch}"
  if [ "$archive" = "zip" ]; then
    ( cd "$stage" && zip -q "${DIST}/${base}.zip" "tokopt${ext}" )
  else
    # -C "$stage" so the archive root contains a bare `tokopt`, no leading dir.
    tar -czf "${DIST}/${base}.tar.gz" -C "$stage" "tokopt${ext}"
  fi

  rm -rf "$stage"
done

ls -lh "$DIST"
```

**Per-archive sanity checks** (run on the host platform — typically
`linux/amd64`):

```bash
cd "$DIST"
mkdir -p extracted && cd extracted
tar -xzf "../tokopt-v${VERSION}-linux-amd64.tar.gz"
./tokopt --version
# Expected: tokopt version v0.1.0
cd .. && rm -rf extracted
```

If `tokopt --version` prints `dev` instead of the tag, the `-ldflags`
`-X main.version=...` path is wrong — see _Common pitfalls_.

---

## Step 4 — Generate `SHA256SUMS`

```bash
cd "${BIN_REPO}/dist"
sha256sum tokopt-v${VERSION}-* > SHA256SUMS

# Verify what was just written.
sha256sum -c SHA256SUMS
```

The format must match the existing `dist/SHA256SUMS`: one line per asset,
`<sha256>  <filename>`, no leading `*` (binary mode marker), one blank-free
line per entry. `install.sh` parses this with
`grep -E "[[:space:]]\*?<asset>$"` so either the GNU two-space form or the
BSD `*<file>` form would work — but stick to GNU two-space for consistency.

On macOS use `shasum -a 256` instead of `sha256sum`; the output format is
identical.

---

## Step 5 — Smoke-test `install.sh` against the local archives

`scripts/install.sh` does not yet support a `--base-url` override (it
hard-codes `https://github.com/shinyay/tokopt/releases/download`), so the
local smoke test is best done by **patching a copy of the script** to point
at a local server.

```bash
cd "${BIN_REPO}/dist"
python3 -m http.server 8000 &
HTTPD_PID=$!

# Make a throwaway copy of the installer with the URLs rewritten.
cp ../scripts/install.sh ./install.local.sh
sed -i \
  -e 's#https://github.com/shinyay/tokopt/releases/download#http://localhost:8000#' \
  -e 's#https://api.github.com/repos/shinyay/tokopt/releases/latest#http://localhost:8000/_unused#' \
  ./install.local.sh

# `--version` skips the GitHub API call entirely, so the second sed is just
# defence-in-depth.
sh ./install.local.sh --version "v${VERSION}" --prefix "$(pwd)/_test"

"$(pwd)/_test/bin/tokopt" --version
# Expected: tokopt version v0.1.0

kill "$HTTPD_PID"
rm -rf install.local.sh _test
```

> **NOTE**: when `install.sh` grows a real `--base-url` flag, replace the
> `sed` patching above with a flag-based invocation and delete this note.

---

## Step 6 — Mirror the CHANGELOG entry into the binary repo

Open `CHANGELOG.md` at the binary repo root. For every released version, the
binary repo CHANGELOG describes the **distribution** (binaries, install
script, docs); it links out to the source repo CHANGELOG for source-side
changes.

For a typical patch:

```markdown
## [X.Y.Z] — YYYY-MM-DD

### Added
- (binary-side additions, e.g. new platform)

### Changed
- (binary-side changes, e.g. install script flags)

### Source release notes
This binary release packages **tokopt vX.Y.Z** from the source repo.
Full source-repo notes:
https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/vX.Y.Z

[X.Y.Z]: https://github.com/shinyay/tokopt/releases/tag/vX.Y.Z
```

Update the `[Unreleased]` compare link at the bottom of the file to point at
the new tag.

---

## Step 7 — Push the binary repo and create the GitHub release

```bash
cd "${BIN_REPO}"
git add CHANGELOG.md
git commit -m "Release v${VERSION}"

git tag -s "v${VERSION}" -m "Release v${VERSION}"
git push origin main "v${VERSION}"
```

Draft the release notes file (kept out of git; it's an input to `gh`):

```bash
cat > release-notes.md <<EOF
tokopt v${VERSION} — pre-built binaries for linux/amd64, linux/arm64,
darwin/amd64, darwin/arm64, and windows/amd64.

## Changes
See [CHANGELOG.md](https://github.com/shinyay/tokopt/blob/v${VERSION}/CHANGELOG.md#${VERSION//./}---$(date +%Y-%m-%d))
for the full distribution-side changes, and the
[source-repo release notes](https://github.com/shinyay/getting-started-with-token-optimization/releases/tag/v${VERSION})
for the underlying CLI changes.

## Install

\`\`\`sh
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
\`\`\`

Pin a version:

\`\`\`sh
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh -s -- --version v${VERSION}
\`\`\`

See [docs/installation.md](https://github.com/shinyay/tokopt/blob/v${VERSION}/docs/installation.md)
for full options, and verify the asset SHA256s against \`SHA256SUMS\`
attached to this release.
EOF
```

Publish the release with all 5 archives + checksums attached:

```bash
gh release create "v${VERSION}" \
  --repo shinyay/tokopt \
  --title "tokopt v${VERSION}" \
  --notes-file release-notes.md \
  dist/tokopt-v${VERSION}-* dist/SHA256SUMS

rm release-notes.md
```

Use `--prerelease` for `-rc.N` / `-pre.N` tags so they are excluded from
`/releases/latest` (and therefore from the installer's auto-detect).

---

## Step 8 — Verify the published release

```bash
gh release view "v${VERSION}" --repo shinyay/tokopt
# Expect 6 assets:
#   tokopt-vX.Y.Z-linux-amd64.tar.gz
#   tokopt-vX.Y.Z-linux-arm64.tar.gz
#   tokopt-vX.Y.Z-darwin-amd64.tar.gz
#   tokopt-vX.Y.Z-darwin-arm64.tar.gz
#   tokopt-vX.Y.Z-windows-amd64.zip
#   SHA256SUMS
```

Then, on a clean machine (or fresh container) — **no overrides**, exactly
the path a user will take:

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
tokopt --version
# Expected: tokopt version v0.1.0
```

Repeat with `--version v${VERSION}` to verify pinning, and once on
`linux/arm64` and `darwin/arm64` if you have access (Apple Silicon Mac,
Raspberry Pi, AWS Graviton, etc.).

---

## Step 9 — Post-release

- Close the milestone for `vX.Y.Z` if you use them.
- Update README badges if any are version-pinned.
- Update `docs/roadmap.md` "Status" line.
- Open the next-version milestone (`vX.Y.(Z+1)` or `vX.(Y+1).0`).
- (Optional) Announce: blog post / social.

---

## Versioning policy (SemVer)

This project follows [SemVer 2.0](https://semver.org/spec/v2.0.0.html):

- **`v0.x.y`** — pre-1.0. Public APIs and JSON output schemas may break in
  **minor** versions. Pin a version in CI scripts.
- **`v1.0.0+`** — stable JSON output schemas; breaking changes require a
  **major** bump.
- **Patch (`x.y.Z`)** — bug-fix only. No new flags, no schema changes,
  no behaviour changes other than fixing a documented bug.
- **Minor (`x.Y.0`)** — backwards-compatible additions: new flags,
  new commands, new optional output fields.
- **Major (`X.0.0`)** — breaking changes.
- **Pre-releases** — `vX.Y.Z-rc.N` (release candidate),
  `vX.Y.Z-pre.N` (preview). Both must be marked `--prerelease` on `gh`.

---

## Hotfix process

1. Branch off the released tag in the **source repo**:

   ```bash
   git checkout -b hotfix/v0.1.1 v0.1.0
   ```

2. Apply (or cherry-pick) the fix. Tests must be green.
3. Bump the **patch** version in `CHANGELOG.md` (source repo) under a new
   `## [0.1.1]` heading.
4. Open a PR, merge, then run the rest of this runbook from
   **Step 2** onward with `VERSION=0.1.1`.

Hotfixes never include new features. If the fix needs a new flag, ship it
as a minor (`0.2.0`) instead.

---

## Rollback

If a release is broken in the wild:

1. **Mark it broken first**: edit the GitHub release notes to add a
   `> ⚠️ DO NOT USE — see vX.Y.(Z+1)` banner at the top. This is visible
   immediately and reaches users who already bookmarked the release URL.
2. Delete the release **and** the tag from both sides:

   ```bash
   # Binary repo
   gh release delete "v${VERSION}" --repo shinyay/tokopt --yes
   git push --delete origin "v${VERSION}"
   git tag -d "v${VERSION}"

   # Source repo
   git push --delete origin "v${VERSION}"
   git tag -d "v${VERSION}"
   ```

   `gh release delete` does **not** delete the underlying git tag — both
   commands above are necessary.

3. Bump to `vX.Y.(Z+1)` and re-release with the fix. Never re-use a tag.

If users may have already installed the broken release: open an issue
using the `bug_report.yml` template format pinned to the top of the repo,
and document the upgrade path in `CHANGELOG.md` under the new patch entry.

---

## Common pitfalls

- **Forgetting `-trimpath`** → builds embed local filesystem paths and
  aren't reproducible. Two builds on different machines will not produce
  byte-identical archives.
- **Forgetting `CGO_ENABLED=0`** → the linux binary dynamically links
  against the host's glibc. It will crash on older distros and on Alpine.
- **Wrong `-X main.version=...` path** → `tokopt --version` prints `dev`
  instead of the tag. The symbol must be `main.version` (the package is
  `main`, the variable is `version` — see
  `tools/tokopt/cmd/tokopt/main.go`). Don't write `cmd/tokopt.version`.
- **Archive root has a leading directory** → `install.sh` does
  `find … -type f -name tokopt | head -n 1` which still works, but the
  contract documented in this repo (and assumed by external tooling) is a
  bare `tokopt` at the archive root. Always `tar -C "$stage" tokopt` and
  `(cd "$stage" && zip … tokopt.exe)`.
- **`SHA256SUMS` regenerated in the wrong directory** → filenames pick up
  a leading path component (`./tokopt-…`) and `install.sh`'s
  `grep -E "…<asset>$"` still matches, but `sha256sum -c` complains.
  Always `cd dist && sha256sum tokopt-v… > SHA256SUMS`.
- **Re-tagging** → never. Bump the patch and tag again.
- **Mixed signed / unsigned tags** → if you signed `v0.1.0`, sign all
  subsequent tags. Mixed history is confusing for downstream verification
  scripts.

---

## Future improvements

- **Reproducible builds** — second machine builds from the same source
  tag and produces byte-identical archives; add a CI job that diffs.
- **Sigstore / cosign signatures** on archives, in addition to checksums.
- **macOS notarization** (required before v1.0; otherwise Gatekeeper
  warning persists for all darwin downloads).
- **Windows code signing**.
- **Move to [GoReleaser](https://goreleaser.com/)** — replaces the manual
  build script in Step 3, the checksum step (Step 4), and most of Step 7
  with a single `goreleaser release` invocation. Worth doing once the
  manual recipe has shipped 2-3 releases and we know what edge cases need
  customising.
