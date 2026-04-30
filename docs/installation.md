# Installing tokopt

`tokopt` ships as a single static binary. The recommended install path is
the bundled installer script — it picks the right archive for your OS/arch,
verifies a SHA-256 checksum, and drops the binary into a sensible place on
your `PATH`.

If you'd rather not pipe `curl` into `sh`, [the manual route](#install-manually)
gets you the same binary with the same checksum guarantee.

---

## TL;DR — one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
```

Then verify:

```bash
tokopt --version
```

If you see a version string, you're done. Jump to the [quickstart](quickstart.md).

If `tokopt` isn't found, the installer printed a `[warn]` line telling you
which directory needs to be added to your `PATH` — see
[Adding to PATH (per-shell)](#adding-to-path-per-shell).

---

## Supported platforms

| OS      | amd64 | arm64       |
| ------- | :---: | :---------: |
| Linux   |  ✅   |     ✅      |
| macOS   |  ✅   |     ✅      |
| Windows |  ✅   | ⏳ planned  |

The installer auto-detects OS and architecture from `uname`. If you're on
an unsupported combination it will refuse to install rather than guess.

---

## Install via the script (recommended)

All examples assume the canonical raw URL:

```text
https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh
```

### Latest release (default)

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
```

The script queries the GitHub Releases API for the latest tag, downloads
that archive, verifies its SHA-256, and installs the binary.

### Pinned version

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \
  | sh -s -- --version v0.1.0
```

Use this in CI or any reproducible environment. Skip the GitHub API call
and pin to an exact release.

### Custom install prefix

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \
  | sh -s -- --prefix "$HOME/.local"
```

This installs into `$HOME/.local/bin/tokopt`. Use this when you don't have
or don't want to use `sudo`.

### Dry-run preview

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \
  | sh -s -- --dry-run
```

Prints the resolved OS, arch, version, archive URL, checksum URL, and
target path — without downloading or installing anything. Useful to
check exactly what `--prefix` and `--version` resolved to.

### Quiet mode

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \
  | sh -s -- --quiet
```

Suppresses informational output. Errors and warnings still print to
stderr.

### All flags

```text
USAGE:
    install.sh [OPTIONS]

OPTIONS:
    --version <VERSION>    Install a specific release tag (e.g. v0.1.0).
                           Overrides TOKOPT_VERSION env var.
    --prefix <DIR>         Install into <DIR>/bin (e.g. --prefix $HOME/.local).
                           Overrides INSTALL_DIR env var.
    --quiet                Suppress informational output (errors still print).
    --dry-run              Print what would happen without downloading or
                           installing anything.
    --help                 Show this help and exit.

ENVIRONMENT:
    TOKOPT_VERSION         Release tag to install. Used when --version is not
                           given. CLI flag takes precedence.
    INSTALL_DIR            Directory to install the binary into. Used when
                           --prefix is not given. CLI flag takes precedence.

PRECEDENCE:
    Version:       --version  >  TOKOPT_VERSION  >  latest GitHub release
    Install dir:   --prefix/bin  >  INSTALL_DIR  >  /usr/local/bin
                                                    (if writable or sudo)
                                                  >  $HOME/.local/bin
```

To see the canonical help locally:

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh \
  -o install.sh && sh install.sh --help
```

---

## Install manually

For users who don't want to pipe to `sh`. You get exactly the same binary,
just with each step in your hands.

1. Visit the latest release page:
   <https://github.com/shinyay/tokopt/releases/latest>

2. Download the archive that matches your OS/arch — for example:

   ```text
   tokopt-v0.1.0-linux-amd64.tar.gz
   tokopt-v0.1.0-darwin-arm64.tar.gz
   tokopt-v0.1.0-windows-amd64.zip
   ```

3. Download `SHA256SUMS` from the same release.

4. Verify the checksum:

   ```bash
   # Linux
   sha256sum -c SHA256SUMS --ignore-missing

   # macOS
   shasum -a 256 -c SHA256SUMS --ignore-missing
   ```

   You should see `tokopt-...: OK`. **If the check fails, stop** — see
   [Troubleshooting install](#troubleshooting-install).

5. Extract:

   ```bash
   tar -xzf tokopt-*.tar.gz
   # or, on Windows:
   #   Expand-Archive tokopt-*.zip
   ```

6. Move the binary onto your `PATH`:

   ```bash
   # System-wide (may need sudo)
   sudo mv tokopt /usr/local/bin/

   # Per-user
   mkdir -p "$HOME/.local/bin"
   mv tokopt "$HOME/.local/bin/"
   ```

7. Verify:

   ```bash
   tokopt --version
   ```

---

## Adding to PATH (per-shell)

If `tokopt --version` returns "command not found" right after install, the
install directory is not on your `PATH`. The installer prints a hint with
the exact directory; the snippets below show the **persistent** form for
each shell.

### bash

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
exec bash
```

On macOS use `~/.bash_profile` instead of `~/.bashrc` for login shells.

### zsh

```zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
exec zsh
```

### fish

```fish
fish_add_path -U $HOME/.local/bin
```

`fish_add_path -U` writes to the universal variable store, so it survives
shell restarts and is the canonical fish idiom.

### PowerShell (Windows)

```powershell
$dir = "$HOME\bin"
[Environment]::SetEnvironmentVariable(
  "Path",
  ([Environment]::GetEnvironmentVariable("Path", "User") + ";" + $dir),
  "User"
)
```

Open a new PowerShell window for the change to take effect.

> Replace `/usr/local/bin` or `$HOME/.local/bin` (or `$HOME\bin`) with
> whatever directory the installer reported.

---

## Verifying the install

```bash
# Prints the version baked into the binary.
tokopt --version

# Sanity check: a subcommand resolves and prints help.
tokopt audit --help
```

Then run a no-op audit on a tiny directory to confirm everything wires
together end-to-end:

```bash
mkdir -p /tmp/tokopt-smoke && tokopt audit /tmp/tokopt-smoke
```

You should see a small report with all three layer totals at `0 tokens`
(the directory is empty). If that works, the binary, the tokenizer, and
the file scanner are all healthy.

For an actual first audit, follow the [quickstart](quickstart.md).

---

## Updating

Re-run the one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
```

The installer is idempotent — if the binary already at the install path
reports the same version as the resolved target, it exits early without
re-downloading. To force a downgrade or pin, use `--version`.

---

## Uninstalling

`tokopt` only writes one file: the binary itself.

```bash
# POSIX
rm "$(which tokopt)"
```

```powershell
# PowerShell
Remove-Item (Get-Command tokopt).Source
```

The install script does **not** modify your shell rcs, write a config
file, or leave anything else behind.

---

## Troubleshooting install

### "Permission denied" writing to `/usr/local/bin`

The default install location needs root write access. Either:

- Re-run with a user prefix: `... | sh -s -- --prefix "$HOME/.local"`
- Or let the script use `sudo` — it auto-detects `sudo` and prompts as
  needed. The script never silently escalates.

### `tokopt: command not found` after install

The install directory is not on your `PATH`. The script prints the
target directory in its `[ ok ]` line — add it to `PATH` using the
[per-shell snippets](#adding-to-path-per-shell), then `exec` your shell
or open a new terminal.

### "Checksum mismatch" / "Refusing to install a tampered or corrupt archive"

**Do not proceed.** Either the network served you a corrupt download or
something is interfering with the release artifacts. Re-try once on a
clean network. If it persists, file a security issue at
<https://github.com/shinyay/tokopt/issues> with the expected/actual
hashes the script printed.

### "Need 'sha256sum' (Linux) or 'shasum' (macOS) for checksum verification"

The script refuses to install without a checksum tool. On Debian/Ubuntu:
`sudo apt-get install coreutils`. On Alpine: `apk add coreutils`. macOS
already has `shasum`.

### "Unsupported OS" / "Unsupported architecture"

You're outside the [supported platform matrix](#supported-platforms).
Download the closest archive manually from the release page; if no
archive matches, open an issue requesting that target.

### Other operational issues

For runtime problems (parse errors, unexpected results, tokenizer issues)
see [`troubleshooting.md`](troubleshooting.md).

---

## What the script does (transparency)

The installer is ~400 lines of POSIX `sh` and does only the following:

- Detects OS and arch from `uname -s` / `uname -m`.
- Resolves the target version using this precedence:
  `--version` → `TOKOPT_VERSION` env var → latest GitHub Release.
- Downloads the archive **and** `SHA256SUMS` over HTTPS (with retry).
- Verifies the SHA-256 checksum of the archive — **mandatory**, no
  `--skip-checksum` escape hatch.
- Extracts the archive into a private temp directory.
- Moves the binary to the install location (using `sudo` only if the
  destination is unwritable and `sudo` is available).
- Cleans up the temp directory on exit, success or failure (via `trap`).
- Prints a `PATH` hint if the install directory isn't on `$PATH`.

It does **not**:

- Phone home or send any telemetry.
- Modify your shell rc files.
- Write anything outside the temp dir and the install destination.
- Touch a config file (there isn't one — `tokopt` is configured via
  flags only).

If you want to read every line before running it, that's encouraged:

```bash
curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | less
```
