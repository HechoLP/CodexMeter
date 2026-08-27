#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
source "${project_root}/Config/Release.env"

identity=${CODE_SIGN_IDENTITY:-}
cache_root=${CODEXMETER_BUILD_CACHE:-"$(getconf DARWIN_USER_CACHE_DIR)/dev.codexmeter.release"}
app_path=${1:-"${CODEXMETER_APP_PATH:-${cache_root}/${PRODUCT_NAME}.app}"}

if [[ -z "${identity}" ]]; then
  print -u2 "Set CODE_SIGN_IDENTITY to a Developer ID Application identity."
  exit 2
fi
if [[ ! -d "${app_path}" ]]; then
  print -u2 "App bundle not found: ${app_path}"
  exit 1
fi

codesign --force --sign "${identity}" --options runtime --timestamp \
  --entitlements "${project_root}/Config/CodexMeter.entitlements" "${app_path}"
codesign --verify --deep --strict --verbose=2 "${app_path}"
