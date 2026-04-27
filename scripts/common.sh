#!/usr/bin/env bash

log() {
  printf 'INFO: %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_file() {
  local file_path="$1"
  if [[ ! -f "${file_path}" ]]; then
    fail "Required file is missing: ${file_path}"
  fi
}

normalize_version() {
  local raw="$1"
  raw="${raw#v}"
  printf '%s\n' "${raw}"
}

normalize_release_tag() {
  local raw="$1"
  if [[ "${raw}" == v* ]]; then
    printf '%s\n' "${raw}"
  else
    printf 'v%s\n' "${raw}"
  fi
}

SHA256_PLACEHOLDER='REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS'
WINGET_V1_0_0_WINDOWS_AMD64_SHA256='313ad7eb643e25517861f8652041cf80d91aa05831497cac9645c147ae94497b'
WINGET_V1_0_0_WINDOWS_ARM64_SHA256='1b31622b3da8eff7acc6e5d78486130488eafc78adc5fa5f09ae9bbcaeb4a312'

get_sha256_from_sums() {
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

resolve_asset_sha256() {
  local sums_file="$1"
  local asset_name="$2"
  local var_label="$3"
  local sha256

  if [[ ! -f "${sums_file}" ]]; then
    warn "${var_label}: SHA256SUMS not found at ${sums_file}; using placeholder."
    printf '%s\n' "${SHA256_PLACEHOLDER}"
    return 0
  fi

  if sha256="$(get_sha256_from_sums "${sums_file}" "${asset_name}")"; then
    printf '%s\n' "${sha256}"
    return 0
  fi

  warn "${var_label}: checksum missing for ${asset_name} in ${sums_file}; using placeholder."
  printf '%s\n' "${SHA256_PLACEHOLDER}"
}

set_sha256_var_from_sums() {
  local var_name="$1"
  local sums_file="$2"
  local asset_name="$3"
  local var_label="$4"
  local current_value="${!var_name:-}"

  if [[ -n "${current_value}" && "${current_value}" != "${SHA256_PLACEHOLDER}" ]]; then
    return 0
  fi

  printf -v "${var_name}" '%s' "$(resolve_asset_sha256 "${sums_file}" "${asset_name}" "${var_label}")"
}

resolve_winget_bundle_sha256() {
  local sums_file="$1"
  local asset_name="$2"
  local var_label="$3"
  local fallback_sha256="$4"
  local sha256

  if [[ -f "${sums_file}" ]]; then
    if sha256="$(get_sha256_from_sums "${sums_file}" "${asset_name}")"; then
      if [[ -n "${fallback_sha256}" && "${sha256}" != "${fallback_sha256}" ]]; then
        warn "${var_label}: local checksum ${sha256} for ${asset_name} differs from confirmed v1.0.0 checksum; using confirmed value."
        printf '%s\n' "${fallback_sha256}"
        return 0
      fi
      printf '%s\n' "${sha256}"
      return 0
    fi

    if [[ -n "${fallback_sha256}" ]]; then
      warn "${var_label}: checksum missing for ${asset_name} in ${sums_file}; using confirmed v1.0.0 checksum."
      printf '%s\n' "${fallback_sha256}"
      return 0
    fi

    warn "${var_label}: checksum missing for ${asset_name} in ${sums_file}; using placeholder."
    printf '%s\n' "${SHA256_PLACEHOLDER}"
    return 0
  fi

  if [[ -n "${fallback_sha256}" ]]; then
    printf '%s\n' "${fallback_sha256}"
    return 0
  fi

  warn "${var_label}: SHA256SUMS not found at ${sums_file}; using placeholder."
  printf '%s\n' "${SHA256_PLACEHOLDER}"
}

set_winget_bundle_sha256_var() {
  local var_name="$1"
  local sums_file="$2"
  local asset_name="$3"
  local var_label="$4"
  local fallback_sha256="$5"
  local current_value="${!var_name:-}"

  if [[ -n "${current_value}" && "${current_value}" != "${SHA256_PLACEHOLDER}" ]]; then
    return 0
  fi

  printf -v "${var_name}" '%s' "$(resolve_winget_bundle_sha256 "${sums_file}" "${asset_name}" "${var_label}" "${fallback_sha256}")"
}

prepare_release_context() {
  local version_input="${1:-${VERSION:-0.0.0}}"
  local tag_input="${2:-${RELEASE_TAG:-${version_input}}}"
  local resolved_root_dir
  local server_base_url
  local tui_base_url
  local winget_base_url
  local server_sums_file
  local tui_sums_file
  local winget_sums_file
  local winget_bundle_dir
  local winget_amd64_fallback_sha256=''
  local winget_arm64_fallback_sha256=''

  VERSION="$(normalize_version "${version_input}")"
  RELEASE_TAG="$(normalize_release_tag "${tag_input}")"

  : "${FLOWLAYER_OWNER:=FlowLayer}"
  : "${FLOWLAYER_REPO:=flowlayer}"

  : "${FLOWLAYER_SERVER_OWNER:=${FLOWLAYER_OWNER}}"
  : "${FLOWLAYER_SERVER_REPO:=${FLOWLAYER_REPO}}"
  : "${FLOWLAYER_TUI_OWNER:=FlowLayer}"
  : "${FLOWLAYER_TUI_REPO:=tui}"

  : "${FLOWLAYER_SERVER_DIST_DIR:=/workspace/server/dist}"
  : "${FLOWLAYER_TUI_DIST_DIR:=/workspace/tui/dist}"

  resolved_root_dir="${ROOT_DIR:-}"
  if [[ -z "${resolved_root_dir}" ]]; then
    if [[ -n "${SCRIPT_DIR:-}" ]]; then
      resolved_root_dir="$(cd "${SCRIPT_DIR}/.." && pwd)"
    else
      resolved_root_dir="$(pwd)"
    fi
  fi

  : "${FLOWLAYER_WINGET_BUNDLE_DIR:=.cache/winget-bundles/v${VERSION}}"
  winget_bundle_dir="${FLOWLAYER_WINGET_BUNDLE_DIR}"
  if [[ "${winget_bundle_dir}" != /* ]]; then
    winget_bundle_dir="${resolved_root_dir}/${winget_bundle_dir}"
  fi

  if [[ "${VERSION}" == '1.0.0' ]]; then
    winget_amd64_fallback_sha256="${WINGET_V1_0_0_WINDOWS_AMD64_SHA256}"
    winget_arm64_fallback_sha256="${WINGET_V1_0_0_WINDOWS_ARM64_SHA256}"
  fi

  server_base_url="https://github.com/${FLOWLAYER_SERVER_OWNER}/${FLOWLAYER_SERVER_REPO}/releases/download/${RELEASE_TAG}"
  tui_base_url="https://github.com/${FLOWLAYER_TUI_OWNER}/${FLOWLAYER_TUI_REPO}/releases/download/${RELEASE_TAG}"
  winget_base_url="https://github.com/${FLOWLAYER_OWNER}/${FLOWLAYER_REPO}/releases/download/${RELEASE_TAG}"

  : "${SERVER_LINUX_AMD64_ASSET:=flowlayer-server-${VERSION}-linux-amd64.tar.gz}"
  : "${SERVER_LINUX_ARM64_ASSET:=flowlayer-server-${VERSION}-linux-arm64.tar.gz}"
  : "${SERVER_DARWIN_AMD64_ASSET:=flowlayer-server-${VERSION}-macos-amd64.tar.gz}"
  : "${SERVER_DARWIN_ARM64_ASSET:=flowlayer-server-${VERSION}-macos-arm64.tar.gz}"
  : "${SERVER_WINDOWS_AMD64_ASSET:=flowlayer-server-${VERSION}-windows-amd64.zip}"
  : "${SERVER_WINDOWS_ARM64_ASSET:=flowlayer-server-${VERSION}-windows-arm64.zip}"

  : "${TUI_LINUX_AMD64_ASSET:=flowlayer-client-tui-${VERSION}-linux-amd64.tar.gz}"
  : "${TUI_LINUX_ARM64_ASSET:=flowlayer-client-tui-${VERSION}-linux-arm64.tar.gz}"
  : "${TUI_DARWIN_AMD64_ASSET:=flowlayer-client-tui-${VERSION}-macos-amd64.tar.gz}"
  : "${TUI_DARWIN_ARM64_ASSET:=flowlayer-client-tui-${VERSION}-macos-arm64.tar.gz}"
  : "${TUI_WINDOWS_AMD64_ASSET:=flowlayer-client-tui-${VERSION}-windows-amd64.zip}"
  : "${TUI_WINDOWS_ARM64_ASSET:=flowlayer-client-tui-${VERSION}-windows-arm64.zip}"

  : "${WINGET_WINDOWS_AMD64_ASSET:=flowlayer-${VERSION}-windows-amd64.zip}"
  : "${WINGET_WINDOWS_ARM64_ASSET:=flowlayer-${VERSION}-windows-arm64.zip}"

  : "${SERVER_LINUX_AMD64_URL:=${server_base_url}/${SERVER_LINUX_AMD64_ASSET}}"
  : "${SERVER_LINUX_ARM64_URL:=${server_base_url}/${SERVER_LINUX_ARM64_ASSET}}"
  : "${SERVER_DARWIN_AMD64_URL:=${server_base_url}/${SERVER_DARWIN_AMD64_ASSET}}"
  : "${SERVER_DARWIN_ARM64_URL:=${server_base_url}/${SERVER_DARWIN_ARM64_ASSET}}"
  : "${SERVER_WINDOWS_AMD64_URL:=${server_base_url}/${SERVER_WINDOWS_AMD64_ASSET}}"
  : "${SERVER_WINDOWS_ARM64_URL:=${server_base_url}/${SERVER_WINDOWS_ARM64_ASSET}}"

  : "${TUI_LINUX_AMD64_URL:=${tui_base_url}/${TUI_LINUX_AMD64_ASSET}}"
  : "${TUI_LINUX_ARM64_URL:=${tui_base_url}/${TUI_LINUX_ARM64_ASSET}}"
  : "${TUI_DARWIN_AMD64_URL:=${tui_base_url}/${TUI_DARWIN_AMD64_ASSET}}"
  : "${TUI_DARWIN_ARM64_URL:=${tui_base_url}/${TUI_DARWIN_ARM64_ASSET}}"
  : "${TUI_WINDOWS_AMD64_URL:=${tui_base_url}/${TUI_WINDOWS_AMD64_ASSET}}"
  : "${TUI_WINDOWS_ARM64_URL:=${tui_base_url}/${TUI_WINDOWS_ARM64_ASSET}}"

  : "${WINGET_WINDOWS_AMD64_URL:=${winget_base_url}/${WINGET_WINDOWS_AMD64_ASSET}}"
  : "${WINGET_WINDOWS_ARM64_URL:=${winget_base_url}/${WINGET_WINDOWS_ARM64_ASSET}}"

  server_sums_file="${FLOWLAYER_SERVER_DIST_DIR}/SHA256SUMS"
  tui_sums_file="${FLOWLAYER_TUI_DIST_DIR}/SHA256SUMS"
  winget_sums_file="${winget_bundle_dir}/SHA256SUMS"

  set_sha256_var_from_sums 'SERVER_LINUX_AMD64_SHA256' "${server_sums_file}" "${SERVER_LINUX_AMD64_ASSET}" 'SERVER_LINUX_AMD64_SHA256'
  set_sha256_var_from_sums 'SERVER_LINUX_ARM64_SHA256' "${server_sums_file}" "${SERVER_LINUX_ARM64_ASSET}" 'SERVER_LINUX_ARM64_SHA256'
  set_sha256_var_from_sums 'SERVER_DARWIN_AMD64_SHA256' "${server_sums_file}" "${SERVER_DARWIN_AMD64_ASSET}" 'SERVER_DARWIN_AMD64_SHA256'
  set_sha256_var_from_sums 'SERVER_DARWIN_ARM64_SHA256' "${server_sums_file}" "${SERVER_DARWIN_ARM64_ASSET}" 'SERVER_DARWIN_ARM64_SHA256'
  set_sha256_var_from_sums 'SERVER_WINDOWS_AMD64_SHA256' "${server_sums_file}" "${SERVER_WINDOWS_AMD64_ASSET}" 'SERVER_WINDOWS_AMD64_SHA256'
  set_sha256_var_from_sums 'SERVER_WINDOWS_ARM64_SHA256' "${server_sums_file}" "${SERVER_WINDOWS_ARM64_ASSET}" 'SERVER_WINDOWS_ARM64_SHA256'

  set_sha256_var_from_sums 'TUI_LINUX_AMD64_SHA256' "${tui_sums_file}" "${TUI_LINUX_AMD64_ASSET}" 'TUI_LINUX_AMD64_SHA256'
  set_sha256_var_from_sums 'TUI_LINUX_ARM64_SHA256' "${tui_sums_file}" "${TUI_LINUX_ARM64_ASSET}" 'TUI_LINUX_ARM64_SHA256'
  set_sha256_var_from_sums 'TUI_DARWIN_AMD64_SHA256' "${tui_sums_file}" "${TUI_DARWIN_AMD64_ASSET}" 'TUI_DARWIN_AMD64_SHA256'
  set_sha256_var_from_sums 'TUI_DARWIN_ARM64_SHA256' "${tui_sums_file}" "${TUI_DARWIN_ARM64_ASSET}" 'TUI_DARWIN_ARM64_SHA256'
  set_sha256_var_from_sums 'TUI_WINDOWS_AMD64_SHA256' "${tui_sums_file}" "${TUI_WINDOWS_AMD64_ASSET}" 'TUI_WINDOWS_AMD64_SHA256'
  set_sha256_var_from_sums 'TUI_WINDOWS_ARM64_SHA256' "${tui_sums_file}" "${TUI_WINDOWS_ARM64_ASSET}" 'TUI_WINDOWS_ARM64_SHA256'

  set_winget_bundle_sha256_var 'WINGET_WINDOWS_AMD64_SHA256' "${winget_sums_file}" "${WINGET_WINDOWS_AMD64_ASSET}" 'WINGET_WINDOWS_AMD64_SHA256' "${winget_amd64_fallback_sha256}"
  set_winget_bundle_sha256_var 'WINGET_WINDOWS_ARM64_SHA256' "${winget_sums_file}" "${WINGET_WINDOWS_ARM64_ASSET}" 'WINGET_WINDOWS_ARM64_SHA256' "${winget_arm64_fallback_sha256}"

  # Backward-compatible aliases kept for templates/scripts still using old variable names.
  : "${DARWIN_AMD64_URL:=${SERVER_DARWIN_AMD64_URL}}"
  : "${DARWIN_AMD64_SHA256:=${SERVER_DARWIN_AMD64_SHA256}}"
  : "${DARWIN_ARM64_URL:=${SERVER_DARWIN_ARM64_URL}}"
  : "${DARWIN_ARM64_SHA256:=${SERVER_DARWIN_ARM64_SHA256}}"
  : "${LINUX_AMD64_URL:=${SERVER_LINUX_AMD64_URL}}"
  : "${LINUX_AMD64_SHA256:=${SERVER_LINUX_AMD64_SHA256}}"
  : "${LINUX_ARM64_URL:=${SERVER_LINUX_ARM64_URL}}"
  : "${LINUX_ARM64_SHA256:=${SERVER_LINUX_ARM64_SHA256}}"
  : "${WINDOWS_AMD64_URL:=${SERVER_WINDOWS_AMD64_URL}}"
  : "${WINDOWS_AMD64_SHA256:=${SERVER_WINDOWS_AMD64_SHA256}}"
  : "${WINDOWS_ARM64_URL:=${SERVER_WINDOWS_ARM64_URL}}"
  : "${WINDOWS_ARM64_SHA256:=${SERVER_WINDOWS_ARM64_SHA256}}"

  export VERSION RELEASE_TAG
  export FLOWLAYER_OWNER FLOWLAYER_REPO
  export FLOWLAYER_SERVER_OWNER FLOWLAYER_SERVER_REPO
  export FLOWLAYER_TUI_OWNER FLOWLAYER_TUI_REPO
  export FLOWLAYER_SERVER_DIST_DIR FLOWLAYER_TUI_DIST_DIR
  export FLOWLAYER_WINGET_BUNDLE_DIR

  export SERVER_LINUX_AMD64_URL SERVER_LINUX_AMD64_SHA256
  export SERVER_LINUX_ARM64_URL SERVER_LINUX_ARM64_SHA256
  export SERVER_DARWIN_AMD64_URL SERVER_DARWIN_AMD64_SHA256
  export SERVER_DARWIN_ARM64_URL SERVER_DARWIN_ARM64_SHA256
  export SERVER_WINDOWS_AMD64_URL SERVER_WINDOWS_AMD64_SHA256
  export SERVER_WINDOWS_ARM64_URL SERVER_WINDOWS_ARM64_SHA256

  export TUI_LINUX_AMD64_URL TUI_LINUX_AMD64_SHA256
  export TUI_LINUX_ARM64_URL TUI_LINUX_ARM64_SHA256
  export TUI_DARWIN_AMD64_URL TUI_DARWIN_AMD64_SHA256
  export TUI_DARWIN_ARM64_URL TUI_DARWIN_ARM64_SHA256
  export TUI_WINDOWS_AMD64_URL TUI_WINDOWS_AMD64_SHA256
  export TUI_WINDOWS_ARM64_URL TUI_WINDOWS_ARM64_SHA256

  export WINGET_WINDOWS_AMD64_URL WINGET_WINDOWS_AMD64_SHA256
  export WINGET_WINDOWS_ARM64_URL WINGET_WINDOWS_ARM64_SHA256

  export DARWIN_AMD64_URL DARWIN_AMD64_SHA256
  export DARWIN_ARM64_URL DARWIN_ARM64_SHA256
  export LINUX_AMD64_URL LINUX_AMD64_SHA256
  export LINUX_ARM64_URL LINUX_ARM64_SHA256
  export WINDOWS_AMD64_URL WINDOWS_AMD64_SHA256
  export WINDOWS_ARM64_URL WINDOWS_ARM64_SHA256
}

render_template() {
  local template_path="$1"
  local output_path="$2"
  local token_list

  if ! command -v awk >/dev/null 2>&1; then
    fail 'awk is required to render templates.'
  fi

  token_list='VERSION RELEASE_TAG FLOWLAYER_OWNER FLOWLAYER_REPO FLOWLAYER_SERVER_OWNER FLOWLAYER_SERVER_REPO FLOWLAYER_TUI_OWNER FLOWLAYER_TUI_REPO SERVER_DARWIN_AMD64_URL SERVER_DARWIN_AMD64_SHA256 SERVER_DARWIN_ARM64_URL SERVER_DARWIN_ARM64_SHA256 SERVER_LINUX_AMD64_URL SERVER_LINUX_AMD64_SHA256 SERVER_LINUX_ARM64_URL SERVER_LINUX_ARM64_SHA256 SERVER_WINDOWS_AMD64_URL SERVER_WINDOWS_AMD64_SHA256 SERVER_WINDOWS_ARM64_URL SERVER_WINDOWS_ARM64_SHA256 TUI_DARWIN_AMD64_URL TUI_DARWIN_AMD64_SHA256 TUI_DARWIN_ARM64_URL TUI_DARWIN_ARM64_SHA256 TUI_LINUX_AMD64_URL TUI_LINUX_AMD64_SHA256 TUI_LINUX_ARM64_URL TUI_LINUX_ARM64_SHA256 TUI_WINDOWS_AMD64_URL TUI_WINDOWS_AMD64_SHA256 TUI_WINDOWS_ARM64_URL TUI_WINDOWS_ARM64_SHA256 WINGET_WINDOWS_AMD64_URL WINGET_WINDOWS_AMD64_SHA256 WINGET_WINDOWS_ARM64_URL WINGET_WINDOWS_ARM64_SHA256 DARWIN_AMD64_URL DARWIN_AMD64_SHA256 DARWIN_ARM64_URL DARWIN_ARM64_SHA256 LINUX_AMD64_URL LINUX_AMD64_SHA256 LINUX_ARM64_URL LINUX_ARM64_SHA256 WINDOWS_AMD64_URL WINDOWS_AMD64_SHA256 WINDOWS_ARM64_URL WINDOWS_ARM64_SHA256'

  awk \
    -v TOKENS="${token_list}" \
    '
function escape_replacement(value, escaped) {
  escaped = value
  # Escape replacement-sensitive characters so gsub keeps values literal.
  gsub(/\\/, "\\\\", escaped)
  gsub(/&/, "\\&", escaped)
  return escaped
}

BEGIN {
  token_count = split(TOKENS, tokens, /[[:space:]]+/)
  for (idx = 1; idx <= token_count; idx++) {
    key = tokens[idx]
    if (key == "") {
      continue
    }
    replacements[key] = escape_replacement(ENVIRON[key])
  }
}

{
  line = $0
  for (idx = 1; idx <= token_count; idx++) {
    key = tokens[idx]
    if (key == "") {
      continue
    }
    gsub("\\{\\{" key "\\}\\}", replacements[key], line)
  }
  print line
}
' "${template_path}" > "${output_path}.tmp"

  mv "${output_path}.tmp" "${output_path}"
}
