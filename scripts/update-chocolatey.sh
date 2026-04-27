#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

VERSION_INPUT="${1:-${VERSION:-0.0.0}}"
RELEASE_INPUT="${2:-${RELEASE_TAG:-${VERSION_INPUT}}}"
prepare_release_context "${VERSION_INPUT}" "${RELEASE_INPUT}"

NUSPEC_TEMPLATE_PATH="${ROOT_DIR}/templates/chocolatey.nuspec.tpl"
NUSPEC_OUTPUT_PATH="${ROOT_DIR}/chocolatey/flowlayer/flowlayer.nuspec"
INSTALL_TEMPLATE_PATH="${ROOT_DIR}/templates/chocolateyinstall.ps1.tpl"
INSTALL_OUTPUT_PATH="${ROOT_DIR}/chocolatey/flowlayer/tools/chocolateyinstall.ps1"

require_file "${NUSPEC_TEMPLATE_PATH}"
require_file "${INSTALL_TEMPLATE_PATH}"
mkdir -p "$(dirname "${NUSPEC_OUTPUT_PATH}")"
mkdir -p "$(dirname "${INSTALL_OUTPUT_PATH}")"
render_template "${NUSPEC_TEMPLATE_PATH}" "${NUSPEC_OUTPUT_PATH}"
render_template "${INSTALL_TEMPLATE_PATH}" "${INSTALL_OUTPUT_PATH}"

log "Generated Chocolatey files: ${NUSPEC_OUTPUT_PATH} and ${INSTALL_OUTPUT_PATH} (VERSION=${VERSION}, RELEASE_TAG=${RELEASE_TAG})"
