#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
source "${project_root}/Config/Release.env"

cache_root=${CODEXMETER_BUILD_CACHE:-"$(getconf DARWIN_USER_CACHE_DIR)/dev.codexmeter.release"}
app_path=${CODEXMETER_APP_PATH:-"${cache_root}/${PRODUCT_NAME}.app"}
"${script_dir}/build_release.sh"
"${script_dir}/package_release.sh"
"${script_dir}/verify_release.sh" "${app_path}"
