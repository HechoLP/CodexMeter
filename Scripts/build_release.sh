#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
source "${project_root}/Config/Release.env"

release_version=${CODEXMETER_VERSION:-${MARKETING_VERSION}}
release_build=${CODEXMETER_BUILD_NUMBER:-${BUILD_NUMBER}}
release_bundle_id=${CODEXMETER_BUNDLE_ID:-${BUNDLE_IDENTIFIER}}
release_repository=${CODEXMETER_RELEASE_REPOSITORY:-${RELEASE_REPOSITORY}}
update_feed_branch=${CODEXMETER_UPDATE_FEED_BRANCH:-${UPDATE_FEED_BRANCH}}
sparkle_feed_url="https://raw.githubusercontent.com/${release_repository}/${update_feed_branch}/appcast.xml"
artifact_root="${project_root}/Artifacts"
cache_root=${CODEXMETER_BUILD_CACHE:-"$(getconf DARWIN_USER_CACHE_DIR)/dev.codexmeter.release"}
app_path=${CODEXMETER_APP_PATH:-"${cache_root}/${PRODUCT_NAME}.app"}
binary_path="${project_root}/.build/apple/Products/Release/${PRODUCT_NAME}"
sparkle_framework="${project_root}/.build/apple/Products/Release/Frameworks/Sparkle.framework"

"${script_dir}/verify_release_context.sh"

cd "${project_root}"
swift build -c release --arch arm64 --arch x86_64

if [[ ! -f "${binary_path}" ]]; then
  print -u2 "Release executable was not produced at ${binary_path}"
  exit 1
fi
if [[ ! -d "${sparkle_framework}" ]]; then
  print -u2 "Sparkle.framework was not produced at ${sparkle_framework}"
  exit 1
fi

if [[ "${app_path:t}" != "${PRODUCT_NAME}.app" ]]; then
  print -u2 "Refusing to replace unexpected app path: ${app_path}"
  exit 1
fi
rm -rf "${app_path}"
mkdir -p "${app_path}/Contents/MacOS" "${app_path}/Contents/Resources" \
  "${app_path}/Contents/Frameworks"
install -m 755 "${binary_path}" "${app_path}/Contents/MacOS/${PRODUCT_NAME}"
install -m 644 "${project_root}/Assets/AppIcon.icns" "${app_path}/Contents/Resources/AppIcon.icns"
install -m 644 "${project_root}/Config/Info.plist" "${app_path}/Contents/Info.plist"
ditto --norsrc --noextattr "${sparkle_framework}" \
  "${app_path}/Contents/Frameworks/Sparkle.framework"

binary_load_commands=$(otool -l "${app_path}/Contents/MacOS/${PRODUCT_NAME}")
if [[ "${binary_load_commands}" != *'@executable_path/../Frameworks'* ]]; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' \
    "${app_path}/Contents/MacOS/${PRODUCT_NAME}"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${PRODUCT_NAME}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${PRODUCT_NAME}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${release_bundle_id}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${release_version}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${release_build}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion ${MINIMUM_SYSTEM_VERSION}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL ${sparkle_feed_url}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey ${SPARKLE_PUBLIC_KEY}" "${app_path}/Contents/Info.plist"

xattr -cr "${app_path}"
codesign --force --sign - --options runtime --entitlements "${project_root}/Config/CodexMeter.entitlements" "${app_path}"
print "Built ${app_path}"
