#!/bin/bash
# Validates that all @mj-biz-apps packages exist on npm before publishing

echo "Checking for new packages that need npm placeholders..."

MISSING=()
CHECKED=0
MAX_RETRIES=3
RETRY_DELAY=2

for pkg_json in $(find packages -name "package.json" -maxdepth 2 -not -path "*/node_modules/*"); do
  name=$(jq -r '.name // ""' "$pkg_json")

  # Only check @mj-biz-apps scoped packages
  if [[ "$name" != @mj-biz-apps/* ]]; then
    continue
  fi

  CHECKED=$((CHECKED + 1))

  # Check if package exists on npm with retry logic.
  # npm view returns exit 1 for BOTH "not found" (E404) and transient errors
  # (rate-limiting from rapid calls, network blips), so a single exit-1 is not
  # conclusive. Retry on the first failure and only treat as missing if it
  # consistently fails — this distinguishes a real 404 from a flaky lookup.
  EXISTS=false
  for attempt in $(seq 1 $MAX_RETRIES); do
    # Use timeout if available (Linux/GitHub Actions), otherwise run without
    # timeout (macOS, where `timeout` is not installed by default).
    if command -v timeout > /dev/null 2>&1; then
      timeout 10 npm view "$name" version > /dev/null 2>&1
    else
      npm view "$name" version > /dev/null 2>&1
    fi
    if [ $? -eq 0 ]; then
      EXISTS=true
      break
    fi
    # Ambiguous failure — wait and retry rather than assuming 404
    if [ "$attempt" -lt "$MAX_RETRIES" ]; then
      sleep $RETRY_DELAY
    fi
  done

  if [ "$EXISTS" = false ]; then
    MISSING+=("$name")
  fi

  # Progress indicator
  if [ $((CHECKED % 10)) -eq 0 ]; then
    echo "  Checked $CHECKED @mj-biz-apps packages..."
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo ""
  echo "::error::Found ${#MISSING[@]} package(s) without npm placeholders:"
  for pkg in "${MISSING[@]}"; do
    echo "  - $pkg"
  done
  echo ""
  echo "📋 Required actions:"
  echo ""
  echo "For each missing package, run:"
  echo "  npx setup-npm-trusted-publish <package-name>"
  echo ""
  echo "Then configure OIDC at:"
  echo "  https://www.npmjs.com/package/<package-name>/access"
  echo ""
  echo "See PUBLISH_SETUP.md for detailed instructions."
  exit 1
fi

echo "All $CHECKED @mj-biz-apps packages exist on npm"
