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

find_single_file() {
  local search_dir="$1"
  local file_name="$2"
  local description="$3"
  local matches

  matches="$(find "${search_dir}" -type f -name "${file_name}" -print)"
  if [[ -z "${matches}" ]]; then
    fail "Could not find ${description} (${file_name}) in ${search_dir}"
  fi

  if [[ "$(printf '%s\n' "${matches}" | wc -l | tr -d '[:space:]')" != "1" ]]; then
    printf '%s\n' "${matches}" >&2
    fail "Expected exactly one ${description} (${file_name}) in ${search_dir}"
  fi

  printf '%s\n' "${matches}"
}

VERSION_INPUT="${1:-1.0.0}"
VERSION="$(normalize_version "${VERSION_INPUT}")"
RELEASE_TAG="$(normalize_release_tag "${RELEASE_TAG:-${VERSION}}")"

SERVER_DIST_DIR="${FLOWLAYER_SERVER_DIST_DIR:-/workspace/server/dist}"
TUI_DIST_DIR="${FLOWLAYER_TUI_DIST_DIR:-/workspace/tui/dist}"
OUT_DIR="${FLOWLAYER_WINGET_BUNDLE_DIR:-.cache/winget-bundles/v${VERSION}}"

if [[ "${OUT_DIR}" != /* ]]; then
  OUT_DIR="${ROOT_DIR}/${OUT_DIR}"
fi

ARCHES=(amd64 arm64)

require_command zip
require_command unzip
require_command find
require_command sha256sum

cd "${ROOT_DIR}"
mkdir -p "${OUT_DIR}"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/flowlayer-winget-bundles.XXXXXX")"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

sha256_sums_path="${OUT_DIR}/SHA256SUMS"
: > "${sha256_sums_path}"

bundle_amd64=''
bundle_arm64=''
sha_amd64=''
sha_arm64=''

for arch in "${ARCHES[@]}"; do
  server_archive="${SERVER_DIST_DIR}/flowlayer-server-${VERSION}-windows-${arch}.zip"
  tui_archive="${TUI_DIST_DIR}/flowlayer-client-tui-${VERSION}-windows-${arch}.zip"

  [[ -f "${server_archive}" ]] || fail "Missing server archive: ${server_archive}"
  [[ -f "${tui_archive}" ]] || fail "Missing TUI archive: ${tui_archive}"

  arch_tmp_dir="${tmp_dir}/${arch}"
  server_extract_dir="${arch_tmp_dir}/server"
  tui_extract_dir="${arch_tmp_dir}/tui"
  stage_dir="${arch_tmp_dir}/stage"
  bundle_path="${OUT_DIR}/flowlayer-${VERSION}-windows-${arch}.zip"

  mkdir -p "${server_extract_dir}" "${tui_extract_dir}" "${stage_dir}"
  unzip -q "${server_archive}" -d "${server_extract_dir}"
  unzip -q "${tui_archive}" -d "${tui_extract_dir}"

  server_exe_path="$(find_single_file "${server_extract_dir}" 'flowlayer-server.exe' "server executable (${arch})")"
  tui_exe_path="$(find_single_file "${tui_extract_dir}" 'flowlayer-client-tui.exe' "TUI executable (${arch})")"

  cp "${server_exe_path}" "${stage_dir}/flowlayer-server.exe"
  cp "${tui_exe_path}" "${stage_dir}/flowlayer-client-tui.exe"

  rm -f "${bundle_path}"
  (
    cd "${stage_dir}"
    zip -q -X "${bundle_path}" flowlayer-server.exe flowlayer-client-tui.exe
  )

  bundle_sha256="$(sha256sum "${bundle_path}" | awk '{print $1}')"
  printf '%s  %s\n' "${bundle_sha256}" "$(basename "${bundle_path}")" >> "${sha256_sums_path}"

  if [[ "${arch}" == 'amd64' ]]; then
    bundle_amd64="${bundle_path}"
    sha_amd64="${bundle_sha256}"
  else
    bundle_arm64="${bundle_path}"
    sha_arm64="${bundle_sha256}"
  fi
done

log "Prepared local Winget Windows bundles (VERSION=${VERSION}, RELEASE_TAG=${RELEASE_TAG})"
printf 'Bundle amd64: %s\n' "${bundle_amd64}"
printf 'SHA256 amd64: %s\n' "${sha_amd64}"
printf 'Bundle arm64: %s\n' "${bundle_arm64}"
printf 'SHA256 arm64: %s\n' "${sha_arm64}"
printf 'SHA256SUMS: %s\n' "${sha256_sums_path}"