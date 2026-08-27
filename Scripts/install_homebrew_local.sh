#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
source "${project_root}/Config/Release.env"

tap_name=${CODEXMETER_LOCAL_TAP:-hechop/codexmeter-local}
release_version=${CODEXMETER_VERSION:-${MARKETING_VERSION}}
artifact_path="${project_root}/Artifacts/${PRODUCT_NAME}-${release_version}.zip"

if ! command -v brew >/dev/null 2>&1; then
  print -u2 "Homebrew is required: https://brew.sh"
  exit 2
fi
export HOMEBREW_NO_AUTO_UPDATE=1
if brew list --cask codexmeter >/dev/null 2>&1; then
  print -u2 "CodexMeter is already installed. Remove it before installing this local candidate."
  exit 1
fi

if [[ ! -f "${artifact_path}" ]]; then
  "${script_dir}/release.sh"
fi

developer_was_enabled=0
if brew developer 2>&1 | grep -q "Developer mode is enabled"; then
  developer_was_enabled=1
fi

restore_developer_mode() {
  if (( developer_was_enabled == 0 )); then
    brew developer off >/dev/null 2>&1 || true
  fi
}
trap restore_developer_mode EXIT

if ! tap_path=$(brew --repository "${tap_name}" 2>/dev/null); then
  brew tap-new --no-git "${tap_name}" >/dev/null
  tap_path=$(brew --repository "${tap_name}")
fi

mkdir -p "${tap_path}/Casks"
local_cask="${tap_path}/Casks/codexmeter.rb"
if [[ -f "${local_cask}" ]] && ! grep -q "Managed by CodexMeter local installer" "${local_cask}"; then
  print -u2 "Refusing to replace an unmanaged Cask: ${local_cask}"
  exit 1
fi

artifact_sha=$(shasum -a 256 "${artifact_path}" | awk '{print $1}')
{
  print "# Managed by CodexMeter local installer"
  awk -v local_url="file://${artifact_path}" -v local_sha="${artifact_sha}" '
    /^  sha256 / { print "  sha256 \"" local_sha "\""; next }
    /^  url / { print "  url \"" local_url "\""; getline; next }
    { print }
  ' "${project_root}/Casks/codexmeter.rb"
} > "${local_cask}"

brew install --cask "${tap_name}/codexmeter"

print "Installed ${PRODUCT_NAME} ${release_version} with Homebrew."
print "Remove it with: brew uninstall --cask codexmeter"
print "Remove the local Tap with: brew untap ${tap_name}"
