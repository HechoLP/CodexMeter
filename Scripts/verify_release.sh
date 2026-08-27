#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
source "${project_root}/Config/Release.env"

release_version=${CODEXMETER_VERSION:-${MARKETING_VERSION}}
release_build=${CODEXMETER_BUILD_NUMBER:-${BUILD_NUMBER}}
release_bundle_id=${CODEXMETER_BUNDLE_ID:-${BUNDLE_IDENTIFIER}}
require_public_release=${CODEXMETER_REQUIRE_PUBLIC_RELEASE:-0}
expected_team_id=${CODE_SIGN_TEAM_ID:-}
cache_root=${CODEXMETER_BUILD_CACHE:-"$(getconf DARWIN_USER_CACHE_DIR)/dev.codexmeter.release"}
app_path=${1:-"${CODEXMETER_APP_PATH:-${cache_root}/${PRODUCT_NAME}.app}"}
artifact_root="${project_root}/Artifacts"
zip_path="${artifact_root}/${PRODUCT_NAME}-${release_version}.zip"
dmg_path="${artifact_root}/${PRODUCT_NAME}-${release_version}.dmg"
temporary_dir=$(mktemp -d)
mount_dir="${temporary_dir}/mounted"
mounted=0

cleanup() {
  if (( mounted )); then
    hdiutil detach -quiet "${mount_dir}" || true
  fi
  rm -rf "${temporary_dir}"
}
trap cleanup EXIT

verify_app() {
  local candidate=$1
  local binary_path="${candidate}/Contents/MacOS/${PRODUCT_NAME}"
  local info_plist="${candidate}/Contents/Info.plist"

  plutil -lint "${info_plist}"
  codesign --verify --deep --strict --verbose=2 "${candidate}"

  local actual_bundle_id actual_version actual_build actual_minimum_system ui_element
  actual_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${info_plist}")
  actual_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${info_plist}")
  actual_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${info_plist}")
  actual_minimum_system=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "${info_plist}")
  ui_element=$(/usr/libexec/PlistBuddy -c "Print :LSUIElement" "${info_plist}")
  if [[ "${actual_bundle_id}" != "${release_bundle_id}" \
      || "${actual_version}" != "${release_version}" \
      || "${actual_build}" != "${release_build}" \
      || "${actual_minimum_system}" != "${MINIMUM_SYSTEM_VERSION}" \
      || "${ui_element:l}" != "true" ]]; then
    print -u2 "Release metadata does not match Config/Release.env: ${candidate}"
    exit 1
  fi

  local architectures
  architectures=$(lipo -archs "${binary_path}")
  if [[ "${architectures}" != *arm64* || "${architectures}" != *x86_64* ]]; then
    print -u2 "Expected a Universal 2 binary, found: ${architectures}"
    exit 1
  fi

  if otool -L "${binary_path}" | grep -Eq '/opt/homebrew|/usr/local'; then
    print -u2 "Release binary links to a developer-local runtime."
    exit 1
  fi

  local signature_details
  signature_details=$(codesign -dv --verbose=4 "${candidate}" 2>&1)
  if [[ "${signature_details}" != *"runtime"* ]]; then
    print -u2 "Hardened Runtime is missing: ${candidate}"
    exit 1
  fi

  local entitlement_json
  entitlement_json=$(codesign -d --entitlements :- "${candidate}" 2>/dev/null \
    | plutil -convert json -o - -)
  if [[ "${entitlement_json}" != "{}" ]]; then
    print -u2 "Unexpected release entitlements: ${candidate}"
    exit 1
  fi

  if [[ "${require_public_release}" == "1" ]]; then
    if [[ -z "${expected_team_id}" ]]; then
      print -u2 "CODE_SIGN_TEAM_ID is required for public release verification."
      exit 2
    fi
    if [[ "${signature_details}" != *"Authority=Developer ID Application:"* \
        || "${signature_details}" != *"TeamIdentifier=${expected_team_id}"* ]]; then
      print -u2 "Expected Developer ID signature for team ${expected_team_id}: ${candidate}"
      exit 1
    fi
    xcrun stapler validate "${candidate}"
    spctl --assess --type execute --verbose=4 "${candidate}"
  fi
  print "Verified ${candidate} (${architectures})"
}

verify_app "${app_path}"

if [[ ! -f "${zip_path}" || ! -f "${dmg_path}" ]]; then
  print -u2 "Packaged ZIP or DMG is missing."
  exit 1
fi

(
  cd "${artifact_root}"
  shasum -a 256 -c "${zip_path:t}.sha256"
  shasum -a 256 -c "${dmg_path:t}.sha256"
)

ditto -x -k "${zip_path}" "${temporary_dir}/zip"
verify_app "${temporary_dir}/zip/${PRODUCT_NAME}.app"

mkdir -p "${mount_dir}"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "${mount_dir}" "${dmg_path}"
mounted=1
verify_app "${mount_dir}/${PRODUCT_NAME}.app"
hdiutil detach -quiet "${mount_dir}"
mounted=0

if [[ "${require_public_release}" != "1" ]]; then
  print "Local candidate verified. Public release still requires Developer ID signing and notarization."
fi
