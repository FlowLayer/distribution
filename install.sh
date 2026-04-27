#!/bin/sh

set -eu
if (set -o pipefail) >/dev/null 2>&1; then
  set -o pipefail
fi

info() {
  printf 'INFO: %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Required command is missing: $1"
  fi
}

normalize_os() {
  os_raw="$(uname -s)"
  case "$os_raw" in
    Linux)
      printf 'linux\n'
      ;;
    Darwin)
      printf 'darwin\n'
      ;;
    CYGWIN*|MINGW*|MSYS*|Windows_NT)
      printf 'windows\n'
      ;;
    *)
      fail "Unsupported operating system: $os_raw"
      ;;
  esac
}

normalize_arch() {
  arch_raw="$(uname -m)"
  case "$arch_raw" in
    x86_64|amd64)
      printf 'amd64\n'
      ;;
    arm64|aarch64)
      printf 'arm64\n'
      ;;
    *)
      fail "Unsupported CPU architecture: $arch_raw"
      ;;
  esac
}

require_cmd uname
require_cmd curl
require_cmd tar
require_cmd mktemp
require_cmd find
require_cmd id

FLOWLAYER_OWNER="${FLOWLAYER_OWNER:-FlowLayer}"
FLOWLAYER_REPO="${FLOWLAYER_REPO:-flowlayer}"
FLOWLAYER_VERSION="${FLOWLAYER_VERSION:-latest}"

OS="$(normalize_os)"
ARCH="$(normalize_arch)"

if [ "$OS" = "windows" ]; then
  fail "install.sh does not support Windows. Use Winget, Scoop, or Chocolatey on Windows."
fi

if [ "$FLOWLAYER_VERSION" = "latest" ]; then
  RELEASE_TAG='latest'
  RELEASE_BASE_URL="https://github.com/${FLOWLAYER_OWNER}/${FLOWLAYER_REPO}/releases/latest/download"
else
  case "$FLOWLAYER_VERSION" in
    v*)
      RELEASE_TAG="$FLOWLAYER_VERSION"
      ;;
    *)
      RELEASE_TAG="v${FLOWLAYER_VERSION}"
      ;;
  esac
  RELEASE_BASE_URL="https://github.com/${FLOWLAYER_OWNER}/${FLOWLAYER_REPO}/releases/download/${RELEASE_TAG}"
fi

# TODO: Align archive naming with the exact names used in published GitHub Releases.
ARCHIVE_NAME="flowlayer_${OS}_${ARCH}.tar.gz"
ARCHIVE_URL="${RELEASE_BASE_URL}/${ARCHIVE_NAME}"
SHA256SUMS_URL="${RELEASE_BASE_URL}/SHA256SUMS"

if [ -n "${FLOWLAYER_INSTALL_DIR:-}" ]; then
  INSTALL_DIR="$FLOWLAYER_INSTALL_DIR"
else
  if [ "$(id -u)" -eq 0 ]; then
    INSTALL_DIR='/usr/local/bin'
  else
    if [ -z "${HOME:-}" ]; then
      fail 'HOME is not set for non-root install. Set FLOWLAYER_INSTALL_DIR explicitly.'
    fi
    INSTALL_DIR="${HOME}/.local/bin"
  fi
fi

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t flowlayer-install)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_NAME}"
SHA256SUMS_PATH="${TMP_DIR}/SHA256SUMS"
EXTRACT_DIR="${TMP_DIR}/extract"

mkdir -p "$EXTRACT_DIR"

info "Downloading FlowLayer archive: ${ARCHIVE_URL}"
if ! curl -fL "$ARCHIVE_URL" -o "$ARCHIVE_PATH"; then
  fail "Download failed. URL may not exist yet (placeholder or unreleased artifact): ${ARCHIVE_URL}"
fi

if curl -fsSL "$SHA256SUMS_URL" -o "$SHA256SUMS_PATH"; then
  info 'SHA256SUMS downloaded. Verifying archive checksum.'

  EXPECTED_SHA256="$(awk -v file="$ARCHIVE_NAME" '$2 == file || $2 == "*" file { print $1; exit }' "$SHA256SUMS_PATH")"
  if [ -z "$EXPECTED_SHA256" ]; then
    fail "SHA256SUMS exists but has no checksum entry for ${ARCHIVE_NAME}"
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL_SHA256="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    ACTUAL_SHA256="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
  else
    fail 'SHA256SUMS is available but no checksum tool found (need sha256sum or shasum).'
  fi

  if [ "$EXPECTED_SHA256" != "$ACTUAL_SHA256" ]; then
    fail "SHA256 mismatch for ${ARCHIVE_NAME}. Expected ${EXPECTED_SHA256}, got ${ACTUAL_SHA256}."
  fi

  info 'Checksum verification passed.'
else
  warn "SHA256SUMS is not available at ${SHA256SUMS_URL}. Skipping checksum verification."
fi

info 'Extracting archive.'
if ! tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"; then
  fail "Failed to extract archive: ${ARCHIVE_PATH}"
fi

SERVER_BIN="$(find "$EXTRACT_DIR" -type f -name 'flowlayer-server' | head -n 1 || true)"
CLIENT_BIN="$(find "$EXTRACT_DIR" -type f -name 'flowlayer-client-tui' | head -n 1 || true)"

if [ -z "$SERVER_BIN" ] || [ -z "$CLIENT_BIN" ]; then
  fail 'Required binaries not found after extraction (flowlayer-server, flowlayer-client-tui).'
fi

mkdir -p "$INSTALL_DIR"

cp "$SERVER_BIN" "${INSTALL_DIR}/flowlayer-server"
cp "$CLIENT_BIN" "${INSTALL_DIR}/flowlayer-client-tui"
chmod +x "${INSTALL_DIR}/flowlayer-server" "${INSTALL_DIR}/flowlayer-client-tui"

info "Installed binaries into: ${INSTALL_DIR}"

if "${INSTALL_DIR}/flowlayer-server" --version >/dev/null 2>&1; then
  "${INSTALL_DIR}/flowlayer-server" --version
else
  warn 'flowlayer-server does not support --version or failed to execute.'
fi

if "${INSTALL_DIR}/flowlayer-client-tui" --version >/dev/null 2>&1; then
  "${INSTALL_DIR}/flowlayer-client-tui" --version
else
  warn 'flowlayer-client-tui does not support --version or failed to execute.'
fi

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*)
    info 'Install directory is present in PATH.'
    ;;
  *)
    warn "${INSTALL_DIR} is probably not in PATH. Add it to use FlowLayer binaries directly."
    ;;
esac

info 'Installation script completed.'
