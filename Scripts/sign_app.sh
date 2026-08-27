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

sparkle_framework="${app_path}/Contents/Frameworks/Sparkle.framework"
if [[ ! -d "${sparkle_framework}" ]]; then
  print -u2 "Embedded Sparkle.framework not found: ${sparkle_framework}"
  exit 1
fi

sparkle_version_root="${sparkle_framework}/Versions/Current"
sparkle_nested_code=(
  "${sparkle_version_root}/XPCServices/Downloader.xpc"
  "${sparkle_version_root}/XPCServices/Installer.xpc"
  "${sparkle_version_root}/Updater.app"
  "${sparkle_version_root}/Autoupdate"
  "${sparkle_framework}"
)
for candidate in "${sparkle_nested_code[@]}"; do
  codesign --force --sign "${identity}" --options runtime --timestamp \
    --preserve-metadata=identifier,entitlements,requirements "${candidate}"
done

codesign --force --sign "${identity}" --options runtime --timestamp \
  --entitlements "${project_root}/Config/CodexMeter.entitlements" "${app_path}"
codesign --verify --deep --strict --verbose=2 "${app_path}"
