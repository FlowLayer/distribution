#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() {
  printf 'INFO: %s\n' "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_file() {
  local file_path="$1"
  [[ -f "${file_path}" ]] || fail "Required file is missing: ${file_path}"
}

assert_absent_fixed() {
  local pattern="$1"
  shift
  local matches

  matches="$(grep -R -n -F -- "${pattern}" "$@" || true)"
  if [[ -n "${matches}" ]]; then
    printf '%s\n' "${matches}" >&2
    fail "Unexpected pattern found: ${pattern}"
  fi
}

assert_present_fixed() {
  local pattern="$1"
  shift

  if ! grep -R -q -F -- "${pattern}" "$@"; then
    fail "Expected pattern not found: ${pattern}"
  fi
}

assert_file_contains_fixed() {
  local file_path="$1"
  local pattern="$2"

  if ! grep -F -q -- "${pattern}" "${file_path}"; then
    fail "Expected pattern not found in ${file_path}: ${pattern}"
  fi
}

assert_file_not_contains_fixed() {
  local file_path="$1"
  local pattern="$2"

  if grep -F -q -- "${pattern}" "${file_path}"; then
    fail "Unexpected pattern found in ${file_path}: ${pattern}"
  fi
}

assert_regex_count_at_least() {
  local file_path="$1"
  local regex="$2"
  local minimum="$3"
  local count

  count="$(
    set +o pipefail
    grep -E -o -- "${regex}" "${file_path}" | wc -l | tr -d '[:space:]'
  )"
  if (( count < minimum )); then
    fail "Expected at least ${minimum} matches for regex '${regex}' in ${file_path}, got ${count}"
  fi
}

lookup_sha256_in_sums() {
  local sums_file="$1"
  local asset_name="$2"

  [[ -f "${sums_file}" ]] || return 1

  awk -v target="${asset_name}" '
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
  basename = path_parts[part_count]
  if (file_path == target || basename == target) {
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
' "${sums_file}"
}

resolve_sha256_from_sums_files() {
  local asset_name="$1"
  shift
  local sums_file
  local sha256

  for sums_file in "$@"; do
    if sha256="$(lookup_sha256_in_sums "${sums_file}" "${asset_name}")"; then
      printf '%s\n' "${sha256}"
      return 0
    fi
  done

  return 1
}

cd "${ROOT_DIR}"

TARGET_VERSION="${1:-1.0.0}"
TARGET_VERSION="${TARGET_VERSION#v}"
TARGET_TAG="v${TARGET_VERSION}"
LEGACY_VERSION_MAJOR_MINOR='1.1'
LEGACY_VERSION="${LEGACY_VERSION_MAJOR_MINOR}.0"
LEGACY_TAG="v${LEGACY_VERSION}"
LICENSE_TOKEN_PREFIX='TODO-VERIFY'
LICENSE_TODO_TOKEN="${LICENSE_TOKEN_PREFIX}-LICENSE"

SERVER_DIST_DIR="${FLOWLAYER_SERVER_DIST_DIR:-/workspace/server/dist}"
TUI_DIST_DIR="${FLOWLAYER_TUI_DIST_DIR:-/workspace/tui/dist}"
WINGET_DIST_DIR="${FLOWLAYER_WINGET_DIST_DIR:-/workspace/dist}"
SERVER_SUMS_FILE="${SERVER_DIST_DIR}/SHA256SUMS"
TUI_SUMS_FILE="${TUI_DIST_DIR}/SHA256SUMS"
WINGET_SUMS_FILE="${WINGET_DIST_DIR}/SHA256SUMS"
WINGET_SUMS_CANDIDATES=("${WINGET_SUMS_FILE}" "${SERVER_SUMS_FILE}" "${TUI_SUMS_FILE}")

SEARCH_PATHS=(
  README.md
  install.sh
  homebrew
  winget
  scoop
  chocolatey
  scripts
  templates
  .github
)

if [[ -f "${SERVER_SUMS_FILE}" && -f "${TUI_SUMS_FILE}" ]]; then
  MODE='local-dist'
  log "Mode: ${MODE}. Local SHA256SUMS detected; running release sync for ${TARGET_VERSION}."
  FLOWLAYER_SERVER_DIST_DIR="${SERVER_DIST_DIR}" \
  FLOWLAYER_TUI_DIST_DIR="${TUI_DIST_DIR}" \
    bash scripts/release-sync.sh "${TARGET_VERSION}" "${TARGET_TAG}"
else
  MODE='no-local-dist'
  log "Mode: ${MODE}. Local SHA256SUMS were not found; validating generated files only."
fi

require_file homebrew/Formula/flowlayer.rb
require_file scoop/bucket/flowlayer.json
require_file chocolatey/flowlayer/flowlayer.nuspec
require_file chocolatey/flowlayer/tools/chocolateyinstall.ps1
require_file "winget/manifests/FlowLayer.FlowLayer/${TARGET_VERSION}/FlowLayer.FlowLayer.yaml"
require_file "winget/manifests/FlowLayer.FlowLayer/${TARGET_VERSION}/FlowLayer.FlowLayer.installer.yaml"
require_file "winget/manifests/FlowLayer.FlowLayer/${TARGET_VERSION}/FlowLayer.FlowLayer.locale.en-US.yaml"

WINGET_VERSION_MANIFEST_PATH="winget/manifests/FlowLayer.FlowLayer/${TARGET_VERSION}/FlowLayer.FlowLayer.yaml"
WINGET_INSTALLER_MANIFEST_PATH="winget/manifests/FlowLayer.FlowLayer/${TARGET_VERSION}/FlowLayer.FlowLayer.installer.yaml"
WINGET_LOCALE_MANIFEST_PATH="winget/manifests/FlowLayer.FlowLayer/${TARGET_VERSION}/FlowLayer.FlowLayer.locale.en-US.yaml"
WINGET_LEGACY_MANIFEST_PATH='winget/manifests/FlowLayer.FlowLayer/flowlayer.yaml'

assert_absent_fixed "${LEGACY_VERSION}" "${SEARCH_PATHS[@]}"
assert_absent_fixed "${LEGACY_TAG}" "${SEARCH_PATHS[@]}"
assert_absent_fixed "${LICENSE_TODO_TOKEN}" "${SEARCH_PATHS[@]}"

assert_present_fixed "FlowLayer/flowlayer/releases/download/${TARGET_TAG}/flowlayer-server-" "${SEARCH_PATHS[@]}"
assert_present_fixed "FlowLayer/flowlayer/releases/download/${TARGET_TAG}/flowlayer-client-tui-" "${SEARCH_PATHS[@]}"

legacy_tui_repo_ref='FlowLayer/'
legacy_tui_repo_ref+="tui"
legacy_tui_releases_ref="${legacy_tui_repo_ref}"
legacy_tui_releases_ref+="/releases"
assert_absent_fixed "${legacy_tui_releases_ref}" "${SEARCH_PATHS[@]}"

legacy_tui_releases_url='github.com/'
legacy_tui_releases_url+="${legacy_tui_releases_ref}"
assert_absent_fixed "${legacy_tui_releases_url}" "${SEARCH_PATHS[@]}"

assert_file_contains_fixed scoop/bucket/flowlayer.json '"license": "Proprietary"'
assert_file_contains_fixed "${WINGET_LOCALE_MANIFEST_PATH}" 'License: Proprietary'
assert_file_contains_fixed chocolatey/flowlayer/flowlayer.nuspec 'Proprietary'

assert_file_contains_fixed "${WINGET_INSTALLER_MANIFEST_PATH}" "flowlayer-${TARGET_VERSION}-windows-amd64.zip"
assert_file_contains_fixed "${WINGET_INSTALLER_MANIFEST_PATH}" "flowlayer-${TARGET_VERSION}-windows-arm64.zip"
assert_file_contains_fixed "${WINGET_LOCALE_MANIFEST_PATH}" 'PackageLocale: en-US'
assert_file_contains_fixed "${WINGET_VERSION_MANIFEST_PATH}" 'ManifestType: version'
assert_file_contains_fixed "${WINGET_INSTALLER_MANIFEST_PATH}" 'ManifestType: installer'
assert_file_contains_fixed "${WINGET_LOCALE_MANIFEST_PATH}" 'ManifestType: defaultLocale'
assert_file_not_contains_fixed "${WINGET_INSTALLER_MANIFEST_PATH}" 'split archives'

WINGET_AMD64_ASSET="flowlayer-${TARGET_VERSION}-windows-amd64.zip"
if winget_amd64_sha256="$(resolve_sha256_from_sums_files "${WINGET_AMD64_ASSET}" "${WINGET_SUMS_CANDIDATES[@]}")"; then
  assert_file_contains_fixed "${WINGET_INSTALLER_MANIFEST_PATH}" "${winget_amd64_sha256}"
else
  log "Skipping Winget amd64 checksum assertion: no SHA256 entry found for ${WINGET_AMD64_ASSET}."
fi

WINGET_ARM64_ASSET="flowlayer-${TARGET_VERSION}-windows-arm64.zip"
if winget_arm64_sha256="$(resolve_sha256_from_sums_files "${WINGET_ARM64_ASSET}" "${WINGET_SUMS_CANDIDATES[@]}")"; then
  assert_file_contains_fixed "${WINGET_INSTALLER_MANIFEST_PATH}" "${winget_arm64_sha256}"
else
  log "Skipping Winget arm64 checksum assertion: no SHA256 entry found for ${WINGET_ARM64_ASSET}."
fi

if [[ -f "${WINGET_LEGACY_MANIFEST_PATH}" ]]; then
  fail "Legacy Winget singleton manifest should not exist: ${WINGET_LEGACY_MANIFEST_PATH}"
fi

assert_regex_count_at_least homebrew/Formula/flowlayer.rb 'sha256 "[0-9a-f]{64}"' 2
assert_regex_count_at_least scoop/bucket/flowlayer.json '"[0-9a-f]{64}"' 4
assert_regex_count_at_least chocolatey/flowlayer/flowlayer.nuspec '[0-9a-f]{64}' 4
assert_regex_count_at_least chocolatey/flowlayer/tools/chocolateyinstall.ps1 "^\\\$(serverChecksumX64|serverChecksumArm64|tuiChecksumX64|tuiChecksumArm64)[[:space:]]*=[[:space:]]*'[0-9a-f]{64}'" 4

SHA256_PLACEHOLDER='REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS'
placeholder_hits="$(grep -R -n -F -- "${SHA256_PLACEHOLDER}" homebrew winget scoop chocolatey || true)"
if [[ -n "${placeholder_hits}" ]]; then
  allowed_guard_pattern="^chocolatey/flowlayer/tools/chocolateyinstall.ps1:[0-9][0-9]*:\\\$checksumPlaceholder = '${SHA256_PLACEHOLDER}'$"
  disallowed_placeholder_hits="$(printf '%s\n' "${placeholder_hits}" | grep -E -v -- "${allowed_guard_pattern}" || true)"
  if [[ -n "${disallowed_placeholder_hits}" ]]; then
    printf '%s\n' "${disallowed_placeholder_hits}" >&2
    fail 'Checksum placeholder found outside the explicit Chocolatey guard constant.'
  fi

  if grep -E -q -- "^[[:space:]]*\\\$(serverChecksumX64|serverChecksumArm64|tuiChecksumX64|tuiChecksumArm64)[[:space:]]*=[[:space:]]*'${SHA256_PLACEHOLDER}'" chocolatey/flowlayer/tools/chocolateyinstall.ps1; then
    grep -n -E -- "^[[:space:]]*\\\$(serverChecksumX64|serverChecksumArm64|tuiChecksumX64|tuiChecksumArm64)[[:space:]]*=[[:space:]]*'${SHA256_PLACEHOLDER}'" chocolatey/flowlayer/tools/chocolateyinstall.ps1 >&2
    fail 'Chocolatey effective checksum variables still use the placeholder.'
  fi

  log 'Checksum placeholder is present only as an explicit Chocolatey guard constant.'
fi

printf 'OK: release-sync consistency checks passed (mode=%s, version=%s, tag=%s)\n' "${MODE}" "${TARGET_VERSION}" "${TARGET_TAG}"
