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

prepare_release_context() {
  local version_input="${1:-${VERSION:-0.0.0}}"
  local tag_input="${2:-${RELEASE_TAG:-${version_input}}}"

  VERSION="$(normalize_version "${version_input}")"
  RELEASE_TAG="$(normalize_release_tag "${tag_input}")"

  : "${FLOWLAYER_OWNER:=FlowLayer}"
  : "${FLOWLAYER_REPO:=flowlayer}"

  local base_url="https://github.com/${FLOWLAYER_OWNER}/${FLOWLAYER_REPO}/releases/download/${RELEASE_TAG}"

  : "${DARWIN_AMD64_URL:=${base_url}/flowlayer_darwin_amd64.tar.gz}"
  : "${DARWIN_AMD64_SHA256:=REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS}"

  : "${DARWIN_ARM64_URL:=${base_url}/flowlayer_darwin_arm64.tar.gz}"
  : "${DARWIN_ARM64_SHA256:=REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS}"

  : "${LINUX_AMD64_URL:=${base_url}/flowlayer_linux_amd64.tar.gz}"
  : "${LINUX_AMD64_SHA256:=REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS}"

  : "${LINUX_ARM64_URL:=${base_url}/flowlayer_linux_arm64.tar.gz}"
  : "${LINUX_ARM64_SHA256:=REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS}"

  : "${WINDOWS_AMD64_URL:=${base_url}/flowlayer_windows_amd64.zip}"
  : "${WINDOWS_AMD64_SHA256:=REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS}"

  : "${WINDOWS_ARM64_URL:=${base_url}/flowlayer_windows_arm64.zip}"
  : "${WINDOWS_ARM64_SHA256:=REPLACE_WITH_REAL_SHA256_FROM_RELEASE_SHA256SUMS}"

  export VERSION RELEASE_TAG FLOWLAYER_OWNER FLOWLAYER_REPO
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

  if ! command -v awk >/dev/null 2>&1; then
    fail 'awk is required to render templates.'
  fi

  awk \
    -v VERSION="${VERSION}" \
    -v RELEASE_TAG="${RELEASE_TAG}" \
    -v DARWIN_AMD64_URL="${DARWIN_AMD64_URL}" \
    -v DARWIN_AMD64_SHA256="${DARWIN_AMD64_SHA256}" \
    -v DARWIN_ARM64_URL="${DARWIN_ARM64_URL}" \
    -v DARWIN_ARM64_SHA256="${DARWIN_ARM64_SHA256}" \
    -v LINUX_AMD64_URL="${LINUX_AMD64_URL}" \
    -v LINUX_AMD64_SHA256="${LINUX_AMD64_SHA256}" \
    -v LINUX_ARM64_URL="${LINUX_ARM64_URL}" \
    -v LINUX_ARM64_SHA256="${LINUX_ARM64_SHA256}" \
    -v WINDOWS_AMD64_URL="${WINDOWS_AMD64_URL}" \
    -v WINDOWS_AMD64_SHA256="${WINDOWS_AMD64_SHA256}" \
    -v WINDOWS_ARM64_URL="${WINDOWS_ARM64_URL}" \
    -v WINDOWS_ARM64_SHA256="${WINDOWS_ARM64_SHA256}" \
    '
function escape_replacement(value, escaped) {
  escaped = value
  # Escape replacement-sensitive characters so gsub keeps values literal.
  gsub(/\\/, "\\\\", escaped)
  gsub(/&/, "\\&", escaped)
  return escaped
}

BEGIN {
  VERSION_ESC = escape_replacement(VERSION)
  RELEASE_TAG_ESC = escape_replacement(RELEASE_TAG)

  DARWIN_AMD64_URL_ESC = escape_replacement(DARWIN_AMD64_URL)
  DARWIN_AMD64_SHA256_ESC = escape_replacement(DARWIN_AMD64_SHA256)

  DARWIN_ARM64_URL_ESC = escape_replacement(DARWIN_ARM64_URL)
  DARWIN_ARM64_SHA256_ESC = escape_replacement(DARWIN_ARM64_SHA256)

  LINUX_AMD64_URL_ESC = escape_replacement(LINUX_AMD64_URL)
  LINUX_AMD64_SHA256_ESC = escape_replacement(LINUX_AMD64_SHA256)

  LINUX_ARM64_URL_ESC = escape_replacement(LINUX_ARM64_URL)
  LINUX_ARM64_SHA256_ESC = escape_replacement(LINUX_ARM64_SHA256)

  WINDOWS_AMD64_URL_ESC = escape_replacement(WINDOWS_AMD64_URL)
  WINDOWS_AMD64_SHA256_ESC = escape_replacement(WINDOWS_AMD64_SHA256)

  WINDOWS_ARM64_URL_ESC = escape_replacement(WINDOWS_ARM64_URL)
  WINDOWS_ARM64_SHA256_ESC = escape_replacement(WINDOWS_ARM64_SHA256)
}

{
  gsub(/\{\{VERSION\}\}/, VERSION_ESC)
  gsub(/\{\{RELEASE_TAG\}\}/, RELEASE_TAG_ESC)

  gsub(/\{\{DARWIN_AMD64_URL\}\}/, DARWIN_AMD64_URL_ESC)
  gsub(/\{\{DARWIN_AMD64_SHA256\}\}/, DARWIN_AMD64_SHA256_ESC)

  gsub(/\{\{DARWIN_ARM64_URL\}\}/, DARWIN_ARM64_URL_ESC)
  gsub(/\{\{DARWIN_ARM64_SHA256\}\}/, DARWIN_ARM64_SHA256_ESC)

  gsub(/\{\{LINUX_AMD64_URL\}\}/, LINUX_AMD64_URL_ESC)
  gsub(/\{\{LINUX_AMD64_SHA256\}\}/, LINUX_AMD64_SHA256_ESC)

  gsub(/\{\{LINUX_ARM64_URL\}\}/, LINUX_ARM64_URL_ESC)
  gsub(/\{\{LINUX_ARM64_SHA256\}\}/, LINUX_ARM64_SHA256_ESC)

  gsub(/\{\{WINDOWS_AMD64_URL\}\}/, WINDOWS_AMD64_URL_ESC)
  gsub(/\{\{WINDOWS_AMD64_SHA256\}\}/, WINDOWS_AMD64_SHA256_ESC)

  gsub(/\{\{WINDOWS_ARM64_URL\}\}/, WINDOWS_ARM64_URL_ESC)
  gsub(/\{\{WINDOWS_ARM64_SHA256\}\}/, WINDOWS_ARM64_SHA256_ESC)

  print
}
' "${template_path}" > "${output_path}.tmp"

  mv "${output_path}.tmp" "${output_path}"
}
