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
OUTPUT_PATHS=(
	"${ROOT_DIR}/homebrew/Formula/flowlayer.rb"
	"${ROOT_DIR}/Formula/flowlayer.rb"
)

require_file "${TEMPLATE_PATH}"
for output_path in "${OUTPUT_PATHS[@]}"; do
	mkdir -p "$(dirname "${output_path}")"
	render_template "${TEMPLATE_PATH}" "${output_path}"
	log "Generated ${output_path} (VERSION=${VERSION}, RELEASE_TAG=${RELEASE_TAG})"
done
