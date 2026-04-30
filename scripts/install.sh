#!/bin/sh
# tokopt installer — downloads a pre-built tokopt binary from a GitHub Release
# and installs it onto your PATH.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh -s -- --version v0.1.0
#   curl -fsSL https://raw.githubusercontent.com/shinyay/tokopt/main/scripts/install.sh | sh -s -- --prefix "$HOME/.local"
#
# License: MIT
#
# Note: this file should be made executable with `chmod +x install.sh` when
# installed locally. When piped to `sh` directly (the curl|sh idiom) the
# executable bit is not required.

set -eu

# ---------- constants ----------
REPO_OWNER="shinyay"
REPO_NAME="tokopt"
BIN_NAME="tokopt"
GITHUB_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
RELEASE_BASE="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download"
RELEASE_PAGE="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest"

# ---------- defaults / cli state ----------
ARG_VERSION=""
ARG_PREFIX=""
QUIET=0
DRY_RUN=0

TMPDIR_INSTALL=""

# ---------- output helpers ----------
_have_tty=0
if [ -t 2 ] && command -v tput >/dev/null 2>&1 && tty -s 2>/dev/null; then
    _have_tty=1
fi

_color() {
    # $1 = color code (1=red,2=green,3=yellow,4=blue), $2 = text
    if [ "$_have_tty" -eq 1 ]; then
        printf '%s%s%s' "$(tput setaf "$1" 2>/dev/null || true)" "$2" "$(tput sgr0 2>/dev/null || true)"
    else
        printf '%s' "$2"
    fi
}

info()    { [ "$QUIET" -eq 1 ] && return 0; printf '%s %s\n' "$(_color 4 '[info]')"  "$*" >&2; }
warn()    { printf '%s %s\n' "$(_color 3 '[warn]')"  "$*" >&2; }
error()   { printf '%s %s\n' "$(_color 1 '[error]') " "$*" >&2; }
success() { [ "$QUIET" -eq 1 ] && return 0; printf '%s %s\n' "$(_color 2 '[ ok ]')"  "$*" >&2; }

die() {
    error "$*"
    error "If this keeps failing, download the binary manually from:"
    error "  ${RELEASE_PAGE}"
    exit 1
}

# ---------- cleanup ----------
cleanup() {
    if [ -n "${TMPDIR_INSTALL:-}" ] && [ -d "$TMPDIR_INSTALL" ]; then
        rm -rf "$TMPDIR_INSTALL"
    fi
}
trap cleanup EXIT INT TERM HUP

# ---------- usage ----------
usage() {
    cat <<EOF
${BIN_NAME} installer

USAGE:
    install.sh [OPTIONS]

OPTIONS:
    --version <VERSION>    Install a specific release tag (e.g. v0.1.0).
                           Overrides TOKOPT_VERSION env var.
    --prefix <DIR>         Install into <DIR>/bin (e.g. --prefix \$HOME/.local).
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
    Install dir:   --prefix/bin  >  INSTALL_DIR  >  /usr/local/bin (if writable
                   or sudo available)  >  \$HOME/.local/bin

EXAMPLES:
    # Latest release into the best-available system location
    curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/scripts/install.sh | sh

    # Pinned version
    curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/scripts/install.sh | sh -s -- --version v0.1.0

    # Install into a user-local prefix
    curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/scripts/install.sh | sh -s -- --prefix "\$HOME/.local"

UNINSTALL:
    rm \$(which ${BIN_NAME})

For manual downloads see: ${RELEASE_PAGE}
EOF
}

# ---------- arg parsing ----------
while [ $# -gt 0 ]; do
    case "$1" in
        --version)
            [ $# -ge 2 ] || { error "--version requires an argument"; usage >&2; exit 2; }
            ARG_VERSION="$2"
            shift 2
            ;;
        --version=*)
            ARG_VERSION="${1#--version=}"
            shift
            ;;
        --prefix)
            [ $# -ge 2 ] || { error "--prefix requires an argument"; usage >&2; exit 2; }
            ARG_PREFIX="$2"
            shift 2
            ;;
        --prefix=*)
            ARG_PREFIX="${1#--prefix=}"
            shift
            ;;
        --quiet|-q)
            QUIET=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            error "Unknown argument: $1"
            usage >&2
            exit 2
            ;;
    esac
done

# ---------- prerequisite detection ----------
DOWNLOADER=""
if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
else
    die "Need either 'curl' or 'wget' installed to download files."
fi

command -v tar >/dev/null 2>&1 || die "Need 'tar' installed to extract the archive."

SHA_CMD=""
if command -v sha256sum >/dev/null 2>&1; then
    SHA_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    SHA_CMD="shasum -a 256"
else
    die "Need 'sha256sum' (Linux) or 'shasum' (macOS) for checksum verification."
fi

# ---------- download helpers ----------
# fetch_to URL DEST   — write URL to file DEST; non-zero on HTTP/network failure.
fetch_to() {
    _url="$1"
    _dest="$2"
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -fsSL --retry 3 --retry-delay 2 -o "$_dest" "$_url"
    else
        wget -q -O "$_dest" "$_url"
    fi
}

# fetch_stdout URL   — write URL to stdout; non-zero on HTTP/network failure.
fetch_stdout() {
    _url="$1"
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -fsSL --retry 3 --retry-delay 2 "$_url"
    else
        wget -q -O - "$_url"
    fi
}

# ---------- OS / arch detection ----------
detect_os() {
    _u=$(uname -s 2>/dev/null || echo unknown)
    case "$_u" in
        Linux)  echo linux ;;
        Darwin) echo darwin ;;
        *)
            die "Unsupported OS: $_u. Download a binary manually from ${RELEASE_PAGE}"
            ;;
    esac
}

detect_arch() {
    _m=$(uname -m 2>/dev/null || echo unknown)
    case "$_m" in
        x86_64|amd64)  echo amd64 ;;
        aarch64|arm64) echo arm64 ;;
        *)
            die "Unsupported architecture: $_m. Download a binary manually from ${RELEASE_PAGE}"
            ;;
    esac
}

# ---------- version resolution ----------
resolve_version() {
    if [ -n "$ARG_VERSION" ]; then
        echo "$ARG_VERSION"
        return 0
    fi
    if [ -n "${TOKOPT_VERSION:-}" ]; then
        echo "$TOKOPT_VERSION"
        return 0
    fi
    info "Querying latest release from GitHub API..." >&2
    _json=$(fetch_stdout "$GITHUB_API") || die "Failed to query ${GITHUB_API}"
    # Parse "tag_name": "vX.Y.Z" — first match wins.
    _tag=$(printf '%s\n' "$_json" \
        | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -n 1 \
        | sed -e 's/.*"tag_name"[[:space:]]*:[[:space:]]*"//' -e 's/"$//')
    [ -n "$_tag" ] || die "Could not parse latest release tag from GitHub API response."
    echo "$_tag"
}

# ---------- install dir resolution ----------
# Echos the resolved install dir; never empty on success.
resolve_install_dir() {
    if [ -n "$ARG_PREFIX" ]; then
        echo "${ARG_PREFIX%/}/bin"
        return 0
    fi
    if [ -n "${INSTALL_DIR:-}" ]; then
        echo "${INSTALL_DIR%/}"
        return 0
    fi
    # Try /usr/local/bin: writable, or sudo available.
    if [ -w /usr/local/bin ] 2>/dev/null; then
        echo /usr/local/bin
        return 0
    fi
    if [ -d /usr/local/bin ] && command -v sudo >/dev/null 2>&1; then
        echo /usr/local/bin
        return 0
    fi
    echo "${HOME}/.local/bin"
}

# Whether we'll need sudo to write to $1.
needs_sudo() {
    _d="$1"
    if [ -w "$_d" ] 2>/dev/null; then
        return 1
    fi
    if [ -d "$_d" ]; then
        return 0
    fi
    # Directory does not yet exist — check parent.
    _parent=$(dirname "$_d")
    if [ -w "$_parent" ] 2>/dev/null; then
        return 1
    fi
    return 0
}

# ---------- PATH check ----------
on_path() {
    _d="$1"
    case ":$PATH:" in
        *":$_d:"*) return 0 ;;
        *)         return 1 ;;
    esac
}

print_path_hint() {
    _d="$1"
    warn "${_d} is not on your PATH."
    warn "Add it by running one of the following, then restart your shell:"
    warn ""
    warn "  # bash / zsh"
    warn "  echo 'export PATH=\"${_d}:\$PATH\"' >> ~/.profile"
    warn ""
    warn "  # fish"
    warn "  fish_add_path -U \"${_d}\""
}

# ---------- main ----------
main() {
    OS=$(detect_os)
    ARCH=$(detect_arch)
    VERSION=$(resolve_version)
    INSTALL_TO=$(resolve_install_dir)

    ASSET="${BIN_NAME}-${VERSION}-${OS}-${ARCH}.tar.gz"
    ASSET_URL="${RELEASE_BASE}/${VERSION}/${ASSET}"
    SUMS_URL="${RELEASE_BASE}/${VERSION}/SHA256SUMS"
    DEST="${INSTALL_TO}/${BIN_NAME}"

    info "Plan:"
    info "  os/arch    : ${OS}/${ARCH}"
    info "  version    : ${VERSION}"
    info "  archive    : ${ASSET_URL}"
    info "  checksums  : ${SUMS_URL}"
    info "  install to : ${DEST}"

    # Idempotency check.
    if [ -x "$DEST" ]; then
        _existing=$("$DEST" --version 2>/dev/null || true)
        case "$_existing" in
            *"$VERSION"*)
                success "${BIN_NAME} is already installed at version ${VERSION} (${DEST})."
                if ! on_path "$INSTALL_TO"; then
                    print_path_hint "$INSTALL_TO"
                fi
                exit 0
                ;;
        esac
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        info "--dry-run set; not downloading or installing."
        exit 0
    fi

    # Stage in a temp directory.
    TMPDIR_INSTALL=$(mktemp -d 2>/dev/null || mktemp -d -t tokopt) \
        || die "Could not create temp directory."

    info "Downloading archive..."
    fetch_to "$ASSET_URL" "${TMPDIR_INSTALL}/${ASSET}" \
        || die "Failed to download ${ASSET_URL}"

    info "Downloading SHA256SUMS..."
    fetch_to "$SUMS_URL" "${TMPDIR_INSTALL}/SHA256SUMS" \
        || die "Failed to download ${SUMS_URL}"

    info "Verifying checksum..."
    EXPECTED=$(grep -E "[[:space:]]\\*?${ASSET}\$" "${TMPDIR_INSTALL}/SHA256SUMS" \
        | awk '{print $1}' | head -n 1)
    [ -n "$EXPECTED" ] || die "No checksum for ${ASSET} in SHA256SUMS."

    ACTUAL=$(cd "$TMPDIR_INSTALL" && $SHA_CMD "$ASSET" | awk '{print $1}')
    if [ "$EXPECTED" != "$ACTUAL" ]; then
        error "Checksum mismatch for ${ASSET}!"
        error "  expected: $EXPECTED"
        error "  actual:   $ACTUAL"
        die "Refusing to install a tampered or corrupt archive."
    fi
    success "Checksum OK."

    info "Extracting archive..."
    ( cd "$TMPDIR_INSTALL" && tar -xzf "$ASSET" ) \
        || die "Failed to extract ${ASSET}"

    # Locate the binary inside the extracted tree.
    EXTRACTED_BIN=""
    if [ -f "${TMPDIR_INSTALL}/${BIN_NAME}" ]; then
        EXTRACTED_BIN="${TMPDIR_INSTALL}/${BIN_NAME}"
    else
        # find first match
        EXTRACTED_BIN=$(find "$TMPDIR_INSTALL" -type f -name "$BIN_NAME" -print 2>/dev/null | head -n 1)
    fi
    [ -n "$EXTRACTED_BIN" ] && [ -f "$EXTRACTED_BIN" ] \
        || die "Could not find '${BIN_NAME}' inside the extracted archive."
    chmod +x "$EXTRACTED_BIN" || die "Could not chmod +x extracted binary."

    # Ensure destination directory exists.
    SUDO=""
    if needs_sudo "$INSTALL_TO"; then
        if command -v sudo >/dev/null 2>&1; then
            SUDO="sudo"
            info "Elevated privileges required to write to ${INSTALL_TO}; using sudo."
        else
            die "${INSTALL_TO} is not writable and 'sudo' is not available."
        fi
    fi

    if [ ! -d "$INSTALL_TO" ]; then
        info "Creating ${INSTALL_TO}..."
        $SUDO mkdir -p "$INSTALL_TO" || die "Could not create ${INSTALL_TO}."
    fi

    # Atomic-ish install: move into place.
    info "Installing to ${DEST}..."
    $SUDO mv -f "$EXTRACTED_BIN" "$DEST" || die "Could not install binary to ${DEST}."
    $SUDO chmod 755 "$DEST" || die "Could not chmod 755 ${DEST}."

    success "✓ Installed ${BIN_NAME} ${VERSION} to ${DEST}"

    if ! on_path "$INSTALL_TO"; then
        print_path_hint "$INSTALL_TO"
    fi
}

main "$@"
