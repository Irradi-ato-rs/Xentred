#!/usr/bin/env bash
# rer-doctor.sh (v0.1)
# RER Doctor — Read-only governance health check
# Wraps gov-diff.sh and applies classification.
# NEVER mutates state.

set -euo pipefail

ORG="${ORG:-}"
REPOS_ALLOWLIST="${REPOS_ALLOWLIST:-}"
GH_TOKEN="${GH_TOKEN:-}"

[[ -z "$ORG" ]] && { echo "ERROR: ORG is required"; exit 2; }
[[ -z "$GH_TOKEN" ]] && { echo "ERROR: GH_TOKEN is required"; exit 2; }

DIFF_OUTPUT="$(mktemp)"
SUMMARY="$(mktemp)"

cleanup() {
  rm -f "$DIFF_OUTPUT" "$SUMMARY"
}
trap cleanup EXIT

export ORG
export REPOS_ALLOWLIST
export GH_TOKEN

echo "=== RER Doctor v0.1 ==="
echo "ORG=${ORG}"
echo

# Run governance diff
bash .github/scripts/gov-diff.sh > "$DIFF_OUTPUT"

# Classification counters
ok=0
warn=0
violation=0

current_repo=""

while IFS= read -r line; do
  if [[ "$line" =~ ^---\ (.+)/(.+)\ ---$ ]]; then
    current_repo="${BASH_REMATCH[2]}"
    continue
  fi

  if [[ "$line" =~ \[OK\] ]]; then
    echo "[OK] ${current_repo}"
    ok=$((ok+1))
  fi

  if [[ "$line" =~ \"missing\"|\"extra\" ]]; then
    # Heuristic: any diff involving required check or strict/admin is a violation
    if grep -q "rexce/validate\|strict\|admins_enforced" <<<"$line"; then
      echo "[VIOLATION] ${current_repo}"
      violation=$((violation+1))
    else
      echo "[WARNING] ${current_repo}"
      warn=$((warn+1))
    fi
  fi
done < "$DIFF_OUTPUT"

echo
echo "=== RER Doctor Summary ==="
echo "OK=${ok}"
echo "WARNING=${warn}"
echo "VIOLATION=${violation}"

# Exit codes for automation
# 0 = clean
# 10 = warnings only
# 20 = violations detected
if [[ "$violation" -gt 0 ]]; then
  exit 20
elif [[ "$warn" -gt 0 ]]; then
  exit 10
else
  exit 0
fi