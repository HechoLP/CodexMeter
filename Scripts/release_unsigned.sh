#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
source "${project_root}/Config/Release.env"

cache_root=${CODEXMETER_BUILD_CACHE:-"$(getconf DARWIN_USER_CACHE_DIR)/dev.codexmeter.release"}
app_path=${CODEXMETER_APP_PATH:-"${cache_root}/${PRODUCT_NAME}.app"}

# A certificate-free release must not accidentally inherit a signing identity
# from the caller. Sparkle archives remain authenticated with the separate
# Ed25519 update key when generate_appcast.sh is run.
unset CODE_SIGN_IDENTITY CODE_SIGN_TEAM_ID

CODEXMETER_ADHOC_HARDENED_RUNTIME=0 \
  "${script_dir}/build_release.sh"
"${script_dir}/package_release.sh"
CODEXMETER_REQUIRE_UNSIGNED_RELEASE=1 \
  "${script_dir}/verify_release.sh" "${app_path}"
