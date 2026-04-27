#!/bin/sh

set -eu

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

asset_os() {
  normalized_os="$1"
  case "$normalized_os" in
    linux)
      printf 'linux\n'
      ;;
    darwin)
      printf 'macos\n'
      ;;
    *)
      fail "Unsupported install OS for archives: $normalized_os"
      ;;
  esac
}

extract_sha256_from_sums() {
  sums_file="$1"
  asset_name="$2"

  awk -v target="$asset_name" '
{
  hash = $1
  if (length(hash) != 64 || hash !~ /^[0-9A-Fa-f]+$/) {
    next
  }

  file_path = $0
  sub(/^[0-9A-Fa-f]+[[:space:]]+/, "", file_path)
  sub(/^\*/, "", file_path)
  sub(/^\.\/+/, "", file_path)
  part_count = split(file_path, path_parts, "/")
  base_name = path_parts[part_count]
  if (file_path == target || base_name == target) {
    print tolower(hash)
    found = 1
    exit
  }
}

END {
  if (!found) {
    exit 1
  }
}
' "$sums_file"
}

compute_sha256() {
  artifact_path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$artifact_path" | awk '{print $1}'
    return 0
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$artifact_path" | awk '{print $1}'
    return 0
  fi

  fail 'No checksum command available (need sha256sum or shasum).'
}

verify_archive_checksum() {
  archive_path="$1"
  sums_path="$2"
  archive_name="$3"
  component_label="$4"

  if [ ! -f "$sums_path" ]; then
    warn "$component_label: SHA256SUMS not available at $sums_path. Skipping checksum verification."
    return 0
  fi

  expected_sha256="$(extract_sha256_from_sums "$sums_path" "$archive_name" || true)"
  if [ -z "$expected_sha256" ]; then
    fail "$component_label: SHA256SUMS exists but has no checksum entry for $archive_name"
  fi

  actual_sha256="$(compute_sha256 "$archive_path")"
  if [ "$expected_sha256" != "$actual_sha256" ]; then
    fail "$component_label: SHA256 mismatch for $archive_name. Expected $expected_sha256, got $actual_sha256."
  fi

  info "$component_label: checksum verification passed."
}

resolve_release_tag() {
  owner="$1"
  repo="$2"
  metadata_url="https://api.github.com/repos/${owner}/${repo}/releases/latest"

  latest_tag="$(curl -fsSL "$metadata_url" | awk -F '"' '/"tag_name"[[:space:]]*:/ { if (tag == "") tag = $4 } END { print tag }')"
  if [ -z "$latest_tag" ]; then
    fail "Unable to resolve latest release tag from ${metadata_url}. Set FLOWLAYER_VERSION explicitly."
  fi

  case "$latest_tag" in
    v*)
      printf '%s\n' "$latest_tag"
      ;;
    *)
      printf 'v%s\n' "$latest_tag"
      ;;
  esac
}

normalize_tag_to_version() {
  raw_tag="$1"
  case "$raw_tag" in
    v*)
      printf '%s\n' "${raw_tag#v}"
      ;;
    *)
      printf '%s\n' "$raw_tag"
      ;;
  esac
}

require_cmd uname
require_cmd curl
require_cmd tar
require_cmd mktemp
require_cmd find
require_cmd id
require_cmd awk
require_cmd head

FLOWLAYER_VERSION="${FLOWLAYER_VERSION:-latest}"
FLOWLAYER_OWNER="${FLOWLAYER_OWNER:-FlowLayer}"
FLOWLAYER_REPO="${FLOWLAYER_REPO:-flowlayer}"

FLOWLAYER_SERVER_OWNER="${FLOWLAYER_SERVER_OWNER:-$FLOWLAYER_OWNER}"
FLOWLAYER_SERVER_REPO="${FLOWLAYER_SERVER_REPO:-$FLOWLAYER_REPO}"
FLOWLAYER_TUI_OWNER="${FLOWLAYER_TUI_OWNER:-FlowLayer}"
FLOWLAYER_TUI_REPO="${FLOWLAYER_TUI_REPO:-tui}"

OS="$(normalize_os)"
ARCH="$(normalize_arch)"
ASSET_OS="$(asset_os "$OS")"

if [ "$OS" = "windows" ]; then
  fail "install.sh does not support Windows. Use Winget, Scoop, or Chocolatey on Windows."
fi

if [ "$FLOWLAYER_VERSION" = "latest" ]; then
  RELEASE_TAG="$(resolve_release_tag "$FLOWLAYER_SERVER_OWNER" "$FLOWLAYER_SERVER_REPO")"
  VERSION="$(normalize_tag_to_version "$RELEASE_TAG")"
  info "Resolved latest release tag: ${RELEASE_TAG}"
else
  case "$FLOWLAYER_VERSION" in
    v*)
      RELEASE_TAG="$FLOWLAYER_VERSION"
      ;;
    *)
      RELEASE_TAG="v${FLOWLAYER_VERSION}"
      ;;
  esac
  VERSION="$(normalize_tag_to_version "$RELEASE_TAG")"
fi

SERVER_RELEASE_BASE_URL="https://github.com/${FLOWLAYER_SERVER_OWNER}/${FLOWLAYER_SERVER_REPO}/releases/download/${RELEASE_TAG}"
TUI_RELEASE_BASE_URL="https://github.com/${FLOWLAYER_TUI_OWNER}/${FLOWLAYER_TUI_REPO}/releases/download/${RELEASE_TAG}"

SERVER_ARCHIVE_NAME="flowlayer-server-${VERSION}-${ASSET_OS}-${ARCH}.tar.gz"
TUI_ARCHIVE_NAME="flowlayer-client-tui-${VERSION}-${ASSET_OS}-${ARCH}.tar.gz"

SERVER_ARCHIVE_URL="${SERVER_RELEASE_BASE_URL}/${SERVER_ARCHIVE_NAME}"
TUI_ARCHIVE_URL="${TUI_RELEASE_BASE_URL}/${TUI_ARCHIVE_NAME}"

SERVER_SHA256SUMS_URL="${SERVER_RELEASE_BASE_URL}/SHA256SUMS"
TUI_SHA256SUMS_URL="${TUI_RELEASE_BASE_URL}/SHA256SUMS"

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

SERVER_ARCHIVE_PATH="${TMP_DIR}/${SERVER_ARCHIVE_NAME}"
TUI_ARCHIVE_PATH="${TMP_DIR}/${TUI_ARCHIVE_NAME}"
SERVER_SHA256SUMS_PATH="${TMP_DIR}/server.SHA256SUMS"
TUI_SHA256SUMS_PATH="${TMP_DIR}/tui.SHA256SUMS"
SERVER_EXTRACT_DIR="${TMP_DIR}/server-extract"
TUI_EXTRACT_DIR="${TMP_DIR}/tui-extract"

mkdir -p "$SERVER_EXTRACT_DIR" "$TUI_EXTRACT_DIR"

info "Downloading FlowLayer server archive: ${SERVER_ARCHIVE_URL}"
if ! curl -fL "$SERVER_ARCHIVE_URL" -o "$SERVER_ARCHIVE_PATH"; then
  fail "Server download failed. URL may not exist yet: ${SERVER_ARCHIVE_URL}"
fi

info "Downloading FlowLayer TUI archive: ${TUI_ARCHIVE_URL}"
if ! curl -fL "$TUI_ARCHIVE_URL" -o "$TUI_ARCHIVE_PATH"; then
  fail "TUI download failed. URL may not exist yet: ${TUI_ARCHIVE_URL}"
fi

if curl -fsSL "$SERVER_SHA256SUMS_URL" -o "$SERVER_SHA256SUMS_PATH"; then
  info 'Server SHA256SUMS downloaded.'
else
  warn "Server SHA256SUMS is not available at ${SERVER_SHA256SUMS_URL}."
fi

if curl -fsSL "$TUI_SHA256SUMS_URL" -o "$TUI_SHA256SUMS_PATH"; then
  info 'TUI SHA256SUMS downloaded.'
else
  warn "TUI SHA256SUMS is not available at ${TUI_SHA256SUMS_URL}."
fi

verify_archive_checksum "$SERVER_ARCHIVE_PATH" "$SERVER_SHA256SUMS_PATH" "$SERVER_ARCHIVE_NAME" 'server'
verify_archive_checksum "$TUI_ARCHIVE_PATH" "$TUI_SHA256SUMS_PATH" "$TUI_ARCHIVE_NAME" 'tui'

info 'Extracting server archive.'
if ! tar -xzf "$SERVER_ARCHIVE_PATH" -C "$SERVER_EXTRACT_DIR"; then
  fail "Failed to extract server archive: ${SERVER_ARCHIVE_PATH}"
fi

info 'Extracting TUI archive.'
if ! tar -xzf "$TUI_ARCHIVE_PATH" -C "$TUI_EXTRACT_DIR"; then
  fail "Failed to extract TUI archive: ${TUI_ARCHIVE_PATH}"
fi

SERVER_BIN="$(find "$SERVER_EXTRACT_DIR" -type f -name 'flowlayer-server' | head -n 1 || true)"
CLIENT_BIN="$(find "$TUI_EXTRACT_DIR" -type f -name 'flowlayer-client-tui' | head -n 1 || true)"

if [ -z "$SERVER_BIN" ] || [ -z "$CLIENT_BIN" ]; then
  fail 'Required binaries not found after extraction (flowlayer-server from server archive and flowlayer-client-tui from TUI archive).'
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
