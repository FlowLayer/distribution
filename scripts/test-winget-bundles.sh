#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    fail "Required command is missing: ${command_name}"
  fi
}

assert_zip_layout() {
  local zip_path="$1"
  local arch_label="$2"
  local entries
  local normalized_entries
  local expected_entries

  entries="$(unzip -Z -1 "${zip_path}")"
  normalized_entries="$(printf '%s\n' "${entries}" | sed '/^$/d' | LC_ALL=C sort)"
  expected_entries="$(printf '%s\n' 'flowlayer-client-tui.exe' 'flowlayer-server.exe' | LC_ALL=C sort)"

  if printf '%s\n' "${normalized_entries}" | grep -q '/'; then
    printf '%s\n' "${normalized_entries}" >&2
    fail "ZIP contains subdirectory entries for ${arch_label}: ${zip_path}"
  fi

  if [[ "${normalized_entries}" != "${expected_entries}" ]]; then
    printf 'Expected entries:\n%s\n' "${expected_entries}" >&2
    printf 'Actual entries:\n%s\n' "${normalized_entries}" >&2
    fail "ZIP content mismatch for ${arch_label}: ${zip_path}"
  fi
}

VERSION_INPUT="${1:-1.0.0}"
VERSION="$(normalize_version "${VERSION_INPUT}")"
OUT_DIR="${FLOWLAYER_WINGET_BUNDLE_DIR:-.cache/winget-bundles/v${VERSION}}"

require_command unzip
require_command sha256sum

cd "${ROOT_DIR}"
bash "${SCRIPT_DIR}/build-winget-bundles.sh" "${VERSION}"

amd64_zip="${OUT_DIR}/flowlayer-${VERSION}-windows-amd64.zip"
arm64_zip="${OUT_DIR}/flowlayer-${VERSION}-windows-arm64.zip"
sha_sums_file="${OUT_DIR}/SHA256SUMS"

require_file "${amd64_zip}"
require_file "${arm64_zip}"
require_file "${sha_sums_file}"

assert_zip_layout "${amd64_zip}" 'amd64'
assert_zip_layout "${arm64_zip}" 'arm64'

(
  cd "${OUT_DIR}"
  sha256sum -c SHA256SUMS
)

log "Winget bundle checks passed for VERSION=${VERSION}"