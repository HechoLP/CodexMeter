#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
source "${project_root}/Config/Release.env"

release_version=${CODEXMETER_VERSION:-${MARKETING_VERSION}}
release_build=${CODEXMETER_BUILD_NUMBER:-${BUILD_NUMBER}}
release_bundle_id=${CODEXMETER_BUNDLE_ID:-${BUNDLE_IDENTIFIER}}
artifact_root="${project_root}/Artifacts"
cache_root=${CODEXMETER_BUILD_CACHE:-"$(getconf DARWIN_USER_CACHE_DIR)/dev.codexmeter.release"}
app_path=${CODEXMETER_APP_PATH:-"${cache_root}/${PRODUCT_NAME}.app"}
binary_path="${project_root}/.build/apple/Products/Release/${PRODUCT_NAME}"

cd "${project_root}"
swift build -c release --arch arm64 --arch x86_64

if [[ ! -f "${binary_path}" ]]; then
  print -u2 "Release executable was not produced at ${binary_path}"
  exit 1
fi

if [[ "${app_path:t}" != "${PRODUCT_NAME}.app" ]]; then
  print -u2 "Refusing to replace unexpected app path: ${app_path}"
  exit 1
fi
rm -rf "${app_path}"
mkdir -p "${app_path}/Contents/MacOS" "${app_path}/Contents/Resources"
install -m 755 "${binary_path}" "${app_path}/Contents/MacOS/${PRODUCT_NAME}"
install -m 644 "${project_root}/Assets/AppIcon.icns" "${app_path}/Contents/Resources/AppIcon.icns"
install -m 644 "${project_root}/Config/Info.plist" "${app_path}/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${PRODUCT_NAME}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${PRODUCT_NAME}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${release_bundle_id}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${release_version}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${release_build}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion ${MINIMUM_SYSTEM_VERSION}" "${app_path}/Contents/Info.plist"

xattr -cr "${app_path}"
codesign --force --sign - --options runtime --entitlements "${project_root}/Config/CodexMeter.entitlements" "${app_path}"
print "Built ${app_path}"
