#!/usr/bin/env bash
# Build the current checkout using the fork-only installer, without merging it.
set -euo pipefail
repo="$(git rev-parse --show-toplevel)"
installer_ref="refs/heads/fix/persistent-local-signing"
staging="$(mktemp -d "${TMPDIR:-/tmp}/scrawl-installer.XXXXXX")"
trap 'rm -rf "${staging}"' EXIT
git -C "${repo}" archive "${installer_ref}" scripts/install-app.sh scripts/signing-identity.sh | tar -x -C "${staging}"
export SCRAWL_REPO_DIR="${repo}"
export CARGO_NET_OFFLINE=true
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
cd "${staging}"
./scripts/install-app.sh
