#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

if [[ $# -lt 1 ]]; then
  fail 'Usage: scripts/release-sync.sh <version> [release_tag]'
fi

VERSION_INPUT="$1"
RELEASE_INPUT="${2:-$1}"
prepare_release_context "${VERSION_INPUT}" "${RELEASE_INPUT}"

log "Release sync start (VERSION=${VERSION}, RELEASE_TAG=${RELEASE_TAG})"
log 'By default, URLs and checksums are placeholders unless provided via environment variables.'

for template_path in \
  "${ROOT_DIR}/templates/homebrew-formula.rb.tpl" \
  "${ROOT_DIR}/templates/winget-manifest.yaml.tpl" \
  "${ROOT_DIR}/templates/scoop.json.tpl" \
  "${ROOT_DIR}/templates/chocolatey.nuspec.tpl" \
  "${ROOT_DIR}/templates/chocolateyinstall.ps1.tpl"; do
  require_file "${template_path}"
done

"${SCRIPT_DIR}/update-homebrew.sh" "${VERSION}" "${RELEASE_TAG}"
"${SCRIPT_DIR}/update-winget.sh" "${VERSION}" "${RELEASE_TAG}"
"${SCRIPT_DIR}/update-scoop.sh" "${VERSION}" "${RELEASE_TAG}"
"${SCRIPT_DIR}/update-chocolatey.sh" "${VERSION}" "${RELEASE_TAG}"

log 'Generation complete.'
log 'Checksums must come from SHA256SUMS published in the matching GitHub Release.'
log 'No git commit and no git push were performed.'

if command -v git >/dev/null 2>&1 && git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log 'Current git status --short:'
  git -C "${ROOT_DIR}" status --short
else
  warn 'git not available or repository metadata not detected; skipping git status output.'
fi
