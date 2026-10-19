#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "${fixture}"' EXIT
cat > "${fixture}/security" <<'MOCK'
#!/bin/sh
cat <<'IDENTITIES'
  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Developer ID Application: Example (TEAM)"
  2) BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB "Developer ID Application: Example (TEAM)"
  3) CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC "Local Development"
     3 valid identities found
IDENTITIES
MOCK
chmod +x "${fixture}/security"
export PATH="${fixture}:${PATH}"
resolve() { SCRAWL_SIGN_IDENTITY="$1" bash "${ROOT}/scripts/signing-identity.sh"; }
[[ "$(resolve aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)" == AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA ]]
[[ "$(resolve 'Local Development')" == CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC ]]
if resolve 'Developer ID Application: Example (TEAM)' > /dev/null 2>&1; then
  echo "Ambiguous names must fail" >&2; exit 1
fi
if resolve missing > /dev/null 2>&1; then
  echo "Missing identities must fail" >&2; exit 1
fi
[[ "$(resolve - 2> "${fixture}/warning")" == - ]]
grep -q 'permissions may be lost' "${fixture}/warning"
echo "Signing identity tests passed"
