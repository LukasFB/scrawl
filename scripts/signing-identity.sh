#!/usr/bin/env bash
# Print the selected certificate SHA-1; local git config survives branch switches.
set -euo pipefail
REPO_DIR="${SCRAWL_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "${REPO_DIR}"
requested="${SCRAWL_SIGN_IDENTITY:-$(git config --local --get scrawl.signingIdentity || true)}"
requested="${requested:-Developer ID Application: Christopher Langton (QC99C9JE59)}"
if [[ "${requested}" == "-" ]]; then
  echo "Warning: explicit ad-hoc signing; macOS permissions may be lost after rebuilds." >&2
  echo "-"
  exit 0
fi
matches="$(security find-identity -v -p codesigning | awk -v requested="${requested}" '
  $1 ~ /^[0-9]+\)$/ && length($2) == 40 {
    name = $0
    sub(/^[^"]*"/, "", name)
    sub(/"[^"]*$/, "", name)
    if (toupper($2) == toupper(requested) || name == requested) print $2
  }')"
count="$(printf '%s\n' "${matches}" | awk 'NF { n++ } END { print n+0 }')"
if [[ "${count}" != "1" ]]; then
  echo "No unique valid signing identity matches: ${requested}" >&2
  echo "Choose a certificate SHA-1 from: security find-identity -v -p codesigning" >&2
  echo "Save it for this checkout: git config --local scrawl.signingIdentity <SHA-1>" >&2
  echo "Or set SCRAWL_SIGN_IDENTITY for this invocation. Refusing silent ad-hoc signing." >&2
  exit 1
fi
printf '%s\n' "${matches}"
