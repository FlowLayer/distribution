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

normalize_path() {
  local target_path="$1"
  if [[ "${target_path}" == /* ]]; then
    printf '%s\n' "${target_path}"
  else
    printf '%s\n' "${ROOT_DIR}/${target_path}"
  fi
}

VERSION_INPUT="${1:-1.0.0}"
VERSION="$(normalize_version "${VERSION_INPUT}")"

SERVER_DIST_DIR="${FLOWLAYER_SERVER_DIST_DIR:-/workspace/server/dist}"
TUI_DIST_DIR="${FLOWLAYER_TUI_DIST_DIR:-/workspace/tui/dist}"
GLOBAL_DIST_DIR="${FLOWLAYER_GLOBAL_DIST_DIR:-/workspace/dist}"
GPG_ID="${GPG_ID:-D3372B726ED237D9780CF0F4E4A9366CF07BC7C8}"
SIGN_RELEASE="${SIGN_RELEASE:-0}"

SERVER_DIST_DIR="$(normalize_path "${SERVER_DIST_DIR}")"
TUI_DIST_DIR="$(normalize_path "${TUI_DIST_DIR}")"
GLOBAL_DIST_DIR="$(normalize_path "${GLOBAL_DIST_DIR}")"

SERVER_ARCHIVES=(
  "flowlayer-server-${VERSION}-linux-amd64.tar.gz"
  "flowlayer-server-${VERSION}-linux-arm64.tar.gz"
  "flowlayer-server-${VERSION}-macos-amd64.tar.gz"
  "flowlayer-server-${VERSION}-macos-arm64.tar.gz"
  "flowlayer-server-${VERSION}-windows-amd64.zip"
  "flowlayer-server-${VERSION}-windows-arm64.zip"
)

TUI_ARCHIVES=(
  "flowlayer-client-tui-${VERSION}-linux-amd64.tar.gz"
  "flowlayer-client-tui-${VERSION}-linux-arm64.tar.gz"
  "flowlayer-client-tui-${VERSION}-macos-amd64.tar.gz"
  "flowlayer-client-tui-${VERSION}-macos-arm64.tar.gz"
  "flowlayer-client-tui-${VERSION}-windows-amd64.zip"
  "flowlayer-client-tui-${VERSION}-windows-arm64.zip"
)

tmp_dir=''
gpg_home=''
cleanup() {
  if [[ -n "${tmp_dir}" ]]; then
    rm -rf "${tmp_dir}"
  fi

  if [[ -n "${gpg_home}" ]]; then
    rm -rf "${gpg_home}"
  fi
}
trap cleanup EXIT

prepare_global_dist() {
  rm -rf "${GLOBAL_DIST_DIR}"
  mkdir -p "${GLOBAL_DIST_DIR}"
}

copy_expected_archives() {
  local archive_name
  local source_path

  for archive_name in "${SERVER_ARCHIVES[@]}"; do
    source_path="${SERVER_DIST_DIR}/${archive_name}"
    [[ -f "${source_path}" ]] || fail "Missing server archive: ${source_path}"
    cp "${source_path}" "${GLOBAL_DIST_DIR}/${archive_name}"
  done

  for archive_name in "${TUI_ARCHIVES[@]}"; do
    source_path="${TUI_DIST_DIR}/${archive_name}"
    [[ -f "${source_path}" ]] || fail "Missing TUI archive: ${source_path}"
    cp "${source_path}" "${GLOBAL_DIST_DIR}/${archive_name}"
  done
}

build_windows_bundle() {
  local arch="$1"
  local server_archive="${GLOBAL_DIST_DIR}/flowlayer-server-${VERSION}-windows-${arch}.zip"
  local tui_archive="${GLOBAL_DIST_DIR}/flowlayer-client-tui-${VERSION}-windows-${arch}.zip"
  local bundle_path="${GLOBAL_DIST_DIR}/flowlayer-${VERSION}-windows-${arch}.zip"
  local arch_tmp_dir="${tmp_dir}/${arch}"
  local server_extract_dir="${arch_tmp_dir}/server"
  local tui_extract_dir="${arch_tmp_dir}/tui"
  local stage_dir="${arch_tmp_dir}/stage"
  local server_exe_path
  local tui_exe_path

  [[ -f "${server_archive}" ]] || fail "Missing copied server archive: ${server_archive}"
  [[ -f "${tui_archive}" ]] || fail "Missing copied TUI archive: ${tui_archive}"

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
}

generate_global_checksums() {
  local sums_path="${GLOBAL_DIST_DIR}/SHA256SUMS"

  (
    cd "${GLOBAL_DIST_DIR}"
    find . -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.zip' \) -printf '%P\n' \
      | LC_ALL=C sort \
      | while IFS= read -r archive_name; do
          [[ -n "${archive_name}" ]] || continue
          sha256sum "${archive_name}"
        done
  ) > "${sums_path}"

  [[ -s "${sums_path}" ]] || fail "Generated SHA256SUMS is empty: ${sums_path}"
}

sign_release_files() {
  local sig_path="${GLOBAL_DIST_DIR}/SHA256SUMS.sig"

  require_command gpg
  require_file /gpg/private.asc
  require_file /gpg/public.asc

  rm -f "${sig_path}"

  gpg_home="$(mktemp -d "${TMPDIR:-/tmp}/flowlayer-global-gpg.XXXXXX")"
  chmod 700 "${gpg_home}"

  GNUPGHOME="${gpg_home}" gpg --batch --import /gpg/private.asc
  GNUPGHOME="${gpg_home}" gpg --batch --import /gpg/public.asc

  if ! GNUPGHOME="${gpg_home}" gpg \
    --batch \
    --yes \
    --pinentry-mode loopback \
    --local-user "${GPG_ID}" \
    --output "${sig_path}" \
    --detach-sign "${GLOBAL_DIST_DIR}/SHA256SUMS"; then
    rm -f "${sig_path}"
    fail "GPG signing failed for ${GLOBAL_DIST_DIR}/SHA256SUMS; removed partial signature file"
  fi

  GNUPGHOME="${gpg_home}" gpg \
    --batch \
    --yes \
    --pinentry-mode loopback \
    --output "${GLOBAL_DIST_DIR}/gpg.key" \
    --armor \
    --export "${GPG_ID}"
}

print_summary() {
  local archive_count
  archive_count="$(find "${GLOBAL_DIST_DIR}" -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.zip' \) | wc -l | tr -d '[:space:]')"

  echo
  log "Global release prepared"
  printf 'VERSION=%s\n' "${VERSION}"
  printf 'SERVER_DIST_DIR=%s\n' "${SERVER_DIST_DIR}"
  printf 'TUI_DIST_DIR=%s\n' "${TUI_DIST_DIR}"
  printf 'GLOBAL_DIST_DIR=%s\n' "${GLOBAL_DIST_DIR}"
  printf 'ARCHIVE_COUNT=%s\n' "${archive_count}"
  printf 'SHA256SUMS=%s\n' "${GLOBAL_DIST_DIR}/SHA256SUMS"

  if [[ "${SIGN_RELEASE}" == "1" ]]; then
    printf 'SHA256SUMS.sig=%s\n' "${GLOBAL_DIST_DIR}/SHA256SUMS.sig"
    printf 'gpg.key=%s\n' "${GLOBAL_DIST_DIR}/gpg.key"
  else
    printf 'SIGN_RELEASE=%s (no signature artifacts)\n' "${SIGN_RELEASE}"
  fi

  echo
  ls -lh "${GLOBAL_DIST_DIR}"
}

main() {
  require_command cp
  require_command find
  require_command mktemp
  require_command sha256sum
  require_command sort
  require_command unzip
  require_command zip

  if [[ "${SIGN_RELEASE}" != "0" && "${SIGN_RELEASE}" != "1" ]]; then
    fail "SIGN_RELEASE must be 0 or 1, got: ${SIGN_RELEASE}"
  fi

  prepare_global_dist
  copy_expected_archives

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/flowlayer-global-bundles.XXXXXX")"
  build_windows_bundle amd64
  build_windows_bundle arm64

  generate_global_checksums

  if [[ "${SIGN_RELEASE}" == "1" ]]; then
    sign_release_files
  else
    rm -f "${GLOBAL_DIST_DIR}/SHA256SUMS.sig" "${GLOBAL_DIST_DIR}/gpg.key"
  fi

  print_summary
}

main "$@"