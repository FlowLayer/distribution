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

main() {
  local test_out_dir='/tmp/flowlayer-global-release-test'
  local archive_count

  require_command bash
  require_command find
  require_command grep
  require_command sed
  require_command sha256sum
  require_command sort
  require_command unzip
  require_command wc

  cd "${ROOT_DIR}"

  SIGN_RELEASE=0 FLOWLAYER_GLOBAL_DIST_DIR="${test_out_dir}" bash "${SCRIPT_DIR}/prepare-global-release.sh" 1.0.0

  archive_count="$(find "${test_out_dir}" -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.zip' \) | wc -l | tr -d '[:space:]')"
  [[ "${archive_count}" == '14' ]] || fail "Expected 14 archives, got ${archive_count}"

  require_file "${test_out_dir}/SHA256SUMS"
  (
    cd "${test_out_dir}"
    sha256sum -c SHA256SUMS
  )

  assert_zip_layout "${test_out_dir}/flowlayer-1.0.0-windows-amd64.zip" 'amd64'
  assert_zip_layout "${test_out_dir}/flowlayer-1.0.0-windows-arm64.zip" 'arm64'

  [[ ! -f "${test_out_dir}/SHA256SUMS.sig" ]] || fail 'SHA256SUMS.sig must not exist when SIGN_RELEASE=0'
  [[ ! -f "${test_out_dir}/gpg.key" ]] || fail 'gpg.key must not exist when SIGN_RELEASE=0'

  echo 'OK'
}

main "$@"