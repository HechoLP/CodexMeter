#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}

CODEXMETER_REQUIRE_RELEASE_TAG=1 \
  CODEXMETER_REQUIRE_PUBLIC_REPOSITORY=1 \
  "${script_dir}/verify_release_context.sh"

"${script_dir}/release_unsigned.sh"
"${script_dir}/generate_appcast.sh"

print "Certificate-free stable release artifacts and signed update feed are ready."
