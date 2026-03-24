#!/usr/bin/env bash
# rer-doctor.sh (v0.2.2)
# RER Doctor — Read-only governance health check
#
# Features:
# - Wraps gov-diff.sh (single source of truth)
# - Classifies OK / WARNING / VIOLATION
# - Fork-aware: no secrets, no notifications, no failures
# - Notifies via GitHub Issue on VIOLATION (trusted contexts only)
# - Auto-closes issue when violations return to 0
#
# NEVER mutates governance state.
# Phase-2 safe. Phase-3 compliant.

set -euo pipefail

# -------------------------
# Inputs (env)
# -------------------------
ORG="${ORG:-}"
REPOS_ALLOWLIST="${REPOS_ALLOWLIST:-}"
GH_TOKEN="${GH_TOKEN:-}"
GITHUB_TOKEN_FALLBACK="${GITHUB_TOKEN:-}"

REPO_SLUG="${GITHUB_REPOSITORY:-}"
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"

# -------------------------
# Notification config
# -------------------------
ISSUE_TITLE="🚨 Governance Violation Detected"
ISSUE_LABELS="governance,violation"

# -------------------------
# Guards (minimal)
# -------------------------
[[ -z "${ORG}" ]] && { echo "ERROR: ORG is required"; exit 2; }
[[ -z "${REPO_SLUG}" ]] && { echo "ERROR: GITHUB_REPOSITORY is required"; exit 2; }

command -v curl >/dev/null || { echo "ERROR: curl not found"; exit 2; }
command -v jq   >/dev/null || { echo "ERROR: jq not found"; exit 2; }

# -------------------------
# Fork awareness & token handling
# -------------------------
if [[ -z "${GH_TOKEN}" ]]; then
  echo "INFO: GH_TOKEN not available (likely forked PR)."
  echo "INFO: Running RER Doctor in read-only, no-notification mode."
  FORK_MODE=1

  if [[ -n "${GITHUB_TOKEN_FALLBACK}" ]]; then
    echo "INFO: Falling back to GITHUB_TOKEN (read-only)."
    GH_TOKEN="${GITHUB_TOKEN_FALLBACK}"
    export GH_TOKEN
  else
    echo "ERROR: No GitHub token available for read-only operations."
    exit 2
  fi
else
  FORK_MODE=0
fi

# -------------------------
# API helper (read/write depends on token)
# -------------------------
api() {
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"

  if [[ -n "${data}" ]]; then
    curl -sS -X "${method}" \
      -H "Authorization: Bearer ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "${GITHUB_API_URL%/}/${path#'/'}" \
      -d "${data}"
  else
    curl -sS -X "${method}" \
      -H "Authorization: Bearer ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "${GITHUB_API_URL%/}/${path#'/'}"
  fi
}

# -------------------------
# Issue helpers (trusted contexts only)
# -------------------------
find_open_issue() {
  local resp
  resp="$(api GET "repos/${REPO_SLUG}/issues?state=open&per_page=100")"

  # If response is not an array (e.g., permission error), treat as no issue
  if ! echo "${resp}" | jq -e 'type == "array"' >/dev/null 2>&1; then
    return 0
  fi

  echo "${resp}" \
    | jq -r ".[] | select(.title == \"${ISSUE_TITLE}\") | .number" \
    | head -n 1
}

create_or_update_issue() {
  local body="$1"
  local issue_number

  issue_number="$(find_open_issue)"

  if [[ -n "${issue_number}" ]]; then
    echo "Updating governance violation issue #${issue_number}"
    api PATCH "repos/${REPO_SLUG}/issues/${issue_number}" \
      "$(jq -n --arg body "${body}" '{body:$body}')" >/dev/null
  else
    echo "Creating governance violation issue"
    api POST "repos/${REPO_SLUG}/issues" \
      "$(jq -n \
        --arg title "${ISSUE_TITLE}" \
        --arg body "${body}" \
        --arg labels "${ISSUE_LABELS}" \
        '{title:$title, body:$body, labels:($labels|split(","))}')" >/dev/null
  fi
}

close_issue_if_open() {
  local issue_number
  issue_number="$(find_open_issue)"

  if [[ -n "${issue_number}" ]]; then
    echo "Closing resolved governance violation issue #${issue_number}"

    api POST "repos/${REPO_SLUG}/issues/${issue_number}/comments" \
      "$(jq -n --arg body \
        "✅ Governance violations resolved.

All Phase‑2 invariants are currently satisfied.

Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" \
        '{body:$body}')" >/dev/null

    api PATCH "repos/${REPO_SLUG}/issues/${issue_number}" \
      "$(jq -n '{state:"closed"}')" >/dev/null
  fi
}

# -------------------------
# Temp files
# -------------------------
DIFF_OUTPUT="$(mktemp)"
trap 'rm -f "${DIFF_OUTPUT}"' EXIT

# -------------------------
# Run gov-diff (read-only)
# -------------------------
echo "=== RER Doctor v0.2.2 ==="
echo "ORG=${ORG}"
echo "REPO=${REPO_SLUG}"
echo

export ORG
export REPOS_ALLOWLIST
export GH_TOKEN

bash .github/scripts/gov-diff.sh > "${DIFF_OUTPUT}"

# -------------------------
# Classification
# -------------------------
ok=0
warn=0
violation=0
current_repo=""

while IFS= read -r line; do
  if [[ "${line}" =~ ^---\ (.+)/(.+)\ ---$ ]]; then
    current_repo="${BASH_REMATCH[2]}"
    continue
  fi

  if [[ "${line}" =~ \[OK\] ]]; then
    ok=$((ok+1))
    continue
  fi

  if grep -q '"missing"\|"extra"' <<<"${line}"; then
    if grep -q 'rexce/validate\|strict\|admins_enforced' <<<"${line}"; then
      violation=$((violation+1))
    else
      warn=$((warn+1))
    fi
  fi
done < "${DIFF_OUTPUT}"

echo "OK=${ok} WARNING=${warn} VIOLATION=${violation}"

# -------------------------
# Fork mode: never notify, never fail
# -------------------------
if [[ "${FORK_MODE}" -eq 1 ]]; then
  echo "INFO: Fork mode active — notifications and failure disabled."
  exit 0
fi

# -------------------------
# Trusted contexts: notify / auto-close
# -------------------------
if [[ "${violation}" -gt 0 ]]; then
  issue_body="$(cat <<EOF
## 🚨 Governance Violation Detected

**Repository:** ${REPO_SLUG}  
**Organization:** ${ORG}  
**Timestamp:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

**Workflow Run:** ${GITHUB_SERVER_URL}/${REPO_SLUG}/actions/runs/${GITHUB_RUN_ID}

### Summary
- ✅ OK: ${ok}
- ⚠️ WARNING: ${warn}
- ❌ VIOLATION: ${violation}

Remediation must proceed via a **Governance Change Proposal (GCP)**.
EOF
)"
  create_or_update_issue "${issue_body}"
  exit 20
else
  close_issue_if_open
  [[ "${warn}" -gt 0 ]] && exit 10 || exit 0
fi