#!/usr/bin/env bash
# rer-doctor.sh (v0.1)
# RER Doctor — Read-only governance health check with violation notifications.
# Wraps gov-diff.sh, applies classification, and notifies on VIOLATION only.
# NEVER mutates repo governance state.

set -euo pipefail

# -------------------------
# Inputs (env)
# -------------------------
ORG="${ORG:-}"
REPOS_ALLOWLIST="${REPOS_ALLOWLIST:-}"
GH_TOKEN="${GH_TOKEN:-}"

# Repo slug is needed for issue creation (assumes running in repo context)
REPO_SLUG="${GITHUB_REPOSITORY:-}"
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"

# -------------------------
# Notification config
# -------------------------
ISSUE_TITLE="🚨 Governance Violation Detected"
ISSUE_LABELS="governance,violation"

# -------------------------
# Guards
# -------------------------
[[ -z "${ORG}" ]] && { echo "ERROR: ORG is required"; exit 2; }
[[ -z "${GH_TOKEN}" ]] && { echo "ERROR: GH_TOKEN is required"; exit 2; }
[[ -z "${REPO_SLUG}" ]] && { echo "ERROR: GITHUB_REPOSITORY is required"; exit 2; }

command -v curl >/dev/null || { echo "ERROR: curl not found"; exit 2; }
command -v jq >/dev/null || { echo "ERROR: jq not found"; exit 2; }

# -------------------------
# Helpers
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

create_or_update_issue() {
  local body="$1"

  # Find existing open issue with the same title
  local existing
  existing="$(api GET "repos/${REPO_SLUG}/issues?state=open&per_page=100" \
    | jq -r ".[] | select(.title == \"${ISSUE_TITLE}\") | .number" | head -n 1)"

  if [[ -n "${existing}" ]]; then
    echo "Updating existing governance violation issue #${existing}"
    api PATCH "repos/${REPO_SLUG}/issues/${existing}" \
      "$(jq -n --arg body "${body}" '{body:$body}')" >/dev/null
  else
    echo "Creating new governance violation issue"
    api POST "repos/${REPO_SLUG}/issues" \
      "$(jq -n \
        --arg title "${ISSUE_TITLE}" \
        --arg body "${body}" \
        --arg labels "${ISSUE_LABELS}" \
        '{title:$title, body:$body, labels:($labels|split(","))}')" >/dev/null
  fi
}

# -------------------------
# Temp files
# -------------------------
DIFF_OUTPUT="$(mktemp)"
trap 'rm -f "${DIFF_OUTPUT}"' EXIT

# -------------------------
# Run
# -------------------------
echo "=== RER Doctor v0.1 ==="
echo "ORG=${ORG}"
echo "REPO=${REPO_SLUG}"
echo

export ORG
export REPOS_ALLOWLIST
export GH_TOKEN

# Run the governance diff (read-only)
bash .github/scripts/gov-diff.sh > "${DIFF_OUTPUT}"

# -------------------------
# Classification counters
# -------------------------
ok=0
warn=0
violation=0
current_repo=""

# -------------------------
# Classify output
# -------------------------
while IFS= read -r line; do
  # Repo header lines look like: --- ORG/repo ---
  if [[ "${line}" =~ ^---\ (.+)/(.+)\ ---$ ]]; then
    current_repo="${BASH_REMATCH[2]}"
    continue
  fi

  if [[ "${line}" =~ \[OK\] ]]; then
    echo "[OK] ${current_repo}"
    ok=$((ok+1))
    continue
  fi

  # Any diff block implies WARNING or VIOLATION.
  # Heuristic aligned with Phase-3 classification:
  # - Required check missing/extra
  # - strict/admins_enforced issues => VIOLATION
  if grep -q '"missing"\|"extra"' <<<"${line}"; then
    if grep -q 'rexce/validate\|strict\|admins_enforced' <<<"${line}"; then
      echo "[VIOLATION] ${current_repo}"
      violation=$((violation+1))
    else
      echo "[WARNING] ${current_repo}"
      warn=$((warn+1))
    fi
  fi
done < "${DIFF_OUTPUT}"

echo
echo "=== RER Doctor Summary ==="
echo "OK=${ok}"
echo "WARNING=${warn}"
echo "VIOLATION=${violation}"

# -------------------------
# Notify on VIOLATION only
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

Please investigate and remediate via a **Governance Change Proposal (GCP)**.
EOF
)"
  create_or_update_issue "${issue_body}"
  exit 20
elif [[ "${warn}" -gt 0 ]]; then
  exit 10
else
  exit 0
fi