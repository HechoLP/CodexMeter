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
# A Hardened Runtime host cannot load Sparkle's separately signed framework
# until sign_app.sh gives every nested component the same Developer ID. Keep
# the standalone ad-hoc build runnable; certificate-backed release workflows
# apply Hardened Runtime when they sign the finished bundle.
adhoc_hardened_runtime=${CODEXMETER_ADHOC_HARDENED_RUNTIME:-0}
sparkle_feed_url="https://raw.githubusercontent.com/${release_repository}/${update_feed_branch}/appcast.xml"
artifact_root="${project_root}/Artifacts"
cache_root=${CODEXMETER_BUILD_CACHE:-"$(getconf DARWIN_USER_CACHE_DIR)/dev.codexmeter.release"}
app_path=${CODEXMETER_APP_PATH:-"${cache_root}/${PRODUCT_NAME}.app"}
mkdir -p "${cache_root}"
if [[ -n "${CODEXMETER_SWIFT_SCRATCH_PATH:-}" ]]; then
  swift_scratch_path=${CODEXMETER_SWIFT_SCRATCH_PATH}
  remove_swift_scratch=0
else
  swift_scratch_path=$(mktemp -d "${cache_root}/swift-build.XXXXXX")
  remove_swift_scratch=1
fi
binary_path="${swift_scratch_path}/apple/Products/Release/${PRODUCT_NAME}"
sparkle_framework="${swift_scratch_path}/apple/Products/Release/Frameworks/Sparkle.framework"

cleanup() {
  if [[ "${remove_swift_scratch}" == "1" \
      && "${swift_scratch_path}" == "${cache_root}/swift-build."* ]]; then
    rm -rf -- "${swift_scratch_path}"
  fi
}
trap cleanup EXIT INT TERM

if [[ "${adhoc_hardened_runtime}" != "0" && "${adhoc_hardened_runtime}" != "1" ]]; then
  print -u2 "CODEXMETER_ADHOC_HARDENED_RUNTIME must be 0 or 1."
  exit 2
fi

"${script_dir}/verify_release_context.sh"

cd "${project_root}"
swift build -c release --arch arm64 --arch x86_64 \
  --scratch-path "${swift_scratch_path}"

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
provider_logo_source="${project_root}/Sources/CodexMeter/Resources/ProviderLogos"
provider_logo_destination="${app_path}/Contents/Resources/ProviderLogos"
mkdir -p "${provider_logo_destination}"
for provider_logo in OpenAI Claude; do
  install -m 644 "${provider_logo_source}/${provider_logo}.svg" \
    "${provider_logo_destination}/${provider_logo}.svg"
done
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
if [[ "${adhoc_hardened_runtime}" == "1" ]]; then
  codesign --force --sign - --options runtime \
    --entitlements "${project_root}/Config/CodexMeter.entitlements" "${app_path}"
elif [[ "${adhoc_hardened_runtime}" == "0" ]]; then
  codesign --force --sign - \
    --entitlements "${project_root}/Config/CodexMeter.entitlements" "${app_path}"
fi
print "Built ${app_path}"
