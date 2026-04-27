#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

VERSION_INPUT="${1:-${VERSION:-0.0.0}}"
RELEASE_INPUT="${2:-${RELEASE_TAG:-${VERSION_INPUT}}}"
prepare_release_context "${VERSION_INPUT}" "${RELEASE_INPUT}"

VERSION_TEMPLATE_PATH="${ROOT_DIR}/templates/winget-version.yaml.tpl"
INSTALLER_TEMPLATE_PATH="${ROOT_DIR}/templates/winget-installer.yaml.tpl"
LOCALE_TEMPLATE_PATH="${ROOT_DIR}/templates/winget-locale.en-US.yaml.tpl"

OUTPUT_DIR="${ROOT_DIR}/winget/manifests/FlowLayer.FlowLayer/${VERSION}"
VERSION_OUTPUT_PATH="${OUTPUT_DIR}/FlowLayer.FlowLayer.yaml"
INSTALLER_OUTPUT_PATH="${OUTPUT_DIR}/FlowLayer.FlowLayer.installer.yaml"
LOCALE_OUTPUT_PATH="${OUTPUT_DIR}/FlowLayer.FlowLayer.locale.en-US.yaml"
LEGACY_OUTPUT_PATH="${ROOT_DIR}/winget/manifests/FlowLayer.FlowLayer/flowlayer.yaml"

for template_path in \
	"${VERSION_TEMPLATE_PATH}" \
	"${INSTALLER_TEMPLATE_PATH}" \
	"${LOCALE_TEMPLATE_PATH}"; do
	require_file "${template_path}"
done

mkdir -p "${OUTPUT_DIR}"
render_template "${VERSION_TEMPLATE_PATH}" "${VERSION_OUTPUT_PATH}"
render_template "${INSTALLER_TEMPLATE_PATH}" "${INSTALLER_OUTPUT_PATH}"
render_template "${LOCALE_TEMPLATE_PATH}" "${LOCALE_OUTPUT_PATH}"

if [[ -f "${LEGACY_OUTPUT_PATH}" ]]; then
	rm -f "${LEGACY_OUTPUT_PATH}"
	log "Removed legacy Winget singleton manifest: ${LEGACY_OUTPUT_PATH}"
fi

log "Generated ${VERSION_OUTPUT_PATH} (VERSION=${VERSION}, RELEASE_TAG=${RELEASE_TAG})"
log "Generated ${INSTALLER_OUTPUT_PATH}"
log "Generated ${LOCALE_OUTPUT_PATH}"
