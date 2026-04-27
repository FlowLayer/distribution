#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

VERSION_INPUT="${1:-${VERSION:-0.0.0}}"
RELEASE_INPUT="${2:-${RELEASE_TAG:-${VERSION_INPUT}}}"
prepare_release_context "${VERSION_INPUT}" "${RELEASE_INPUT}"

TEMPLATE_PATH="${ROOT_DIR}/templates/homebrew-formula.rb.tpl"
OUTPUT_PATH="${ROOT_DIR}/homebrew/Formula/flowlayer.rb"

require_file "${TEMPLATE_PATH}"
mkdir -p "$(dirname "${OUTPUT_PATH}")"
render_template "${TEMPLATE_PATH}" "${OUTPUT_PATH}"

log "Generated ${OUTPUT_PATH} (VERSION=${VERSION}, RELEASE_TAG=${RELEASE_TAG})"
