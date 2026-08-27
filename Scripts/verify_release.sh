#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
source "${project_root}/Config/Release.env"

release_version=${CODEXMETER_VERSION:-${MARKETING_VERSION}}
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

  plutil -lint "${candidate}/Contents/Info.plist"
  codesign --verify --deep --strict --verbose=2 "${candidate}"

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
  if [[ "${signature_details}" == *"Authority=Developer ID Application:"* ]]; then
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

if [[ "$(codesign -dv --verbose=4 "${app_path}" 2>&1)" != *"Authority=Developer ID Application:"* ]]; then
  print "Gatekeeper assessment skipped: Developer ID signature is not present."
fi
