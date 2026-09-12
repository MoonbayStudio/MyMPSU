#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

blocked_files="$(git ls-files -co --exclude-standard | grep -Ei '(^|/)(\.env$|.*\.(pem|key|p8|p12|jks|keystore|mobileprovision)$|google-services\.json$|GoogleService-Info\.plist$|credentials[^/]*\.json$|service-account[^/]*\.json$)' || true)"
if [[ -n "$blocked_files" ]]; then
  echo "Refusing to continue: sensitive filenames are tracked:"
  echo "$blocked_files"
  exit 1
fi

secret_files="$(rg -l --no-messages '(-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|ghp_[A-Za-z0-9]{30,}|sk-[A-Za-z0-9_-]{24,}|AKIA[0-9A-Z]{16})' --glob '!*.example' --glob '!**/*.md' . || true)"
if [[ -n "$secret_files" ]]; then
  echo "Potential credential material found in tracked files:"
  echo "$secret_files"
  echo "Only filenames are shown to avoid leaking the value into CI logs."
  exit 1
fi

echo "Tracked-file secret checks passed."
