#!/usr/bin/env bash
# gov-diff.sh (v0.1)
# Phase-3 Governance Diff Engine (READ-ONLY)
# Compares current GitHub branch protection against Phase-2 baseline.
# Emits diffs only. Never mutates state.

set -euo pipefail

ORG="${ORG:-}"
REPOS_ALLOWLIST="${REPOS_ALLOWLIST:-}"
DEFAULT_BRANCH="main"
REQUIRED_CHECK="rexce/validate"

GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"
GH_TOKEN="${GH_TOKEN:-}"

[[ -z "$ORG" ]] && { echo "ERROR: ORG is required"; exit 2; }
if [[ -z "${GH_TOKEN}" ]]; then
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "INFO: GH_TOKEN not available; falling back to GITHUB_TOKEN (read-only)."
    GH_TOKEN="${GITHUB_TOKEN}"
    export GH_TOKEN
  else
    echo "ERROR: No GitHub token available (GH_TOKEN or GITHUB_TOKEN)."
    exit 2
  fi
fi

req() { command -v "$1" >/dev/null || { echo "ERROR: $1 missing"; exit 2; }; }
req curl
req jq

api() {
  curl -sS \
    -H "Authorization: Bearer ${GH_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "${GITHUB_API_URL%/}/$1"
}

split_list() { tr ', ' '\n' | sed '/^\s*$/d'; }

resolve_repos() {
  if [[ -n "${REPOS_ALLOWLIST}" ]]; then
    echo "${REPOS_ALLOWLIST}" | split_list | sort -u
  else
    api "orgs/${ORG}/repos?per_page=100&type=all" |
      jq -r '.[] | select(.archived==false) | .name' | sort -u
  fi
}

normalize_protection() {
  jq -S '{
    pr_required: (.required_pull_request_reviews != null),
    approvals: (.required_pull_request_reviews.required_approving_review_count // 0),
    dismiss_stale: (.required_pull_request_reviews.dismiss_stale_reviews // false),
    strict: (.required_status_checks.strict // false),
    contexts: (.required_status_checks.contexts // []),
    admins_enforced: (
      if .enforce_admins==true or .enforce_admins.enabled==true
      then true else false end
    )
  }'
}

baseline() {
  jq -n --arg check "${REQUIRED_CHECK}" '{
    pr_required: true,
    approvals: 1,
    dismiss_stale: true,
    strict: true,
    contexts: [$check],
    admins_enforced: true
  }'
}

echo "=== Governance Diff Engine v0.1 ==="
echo "ORG=${ORG}"
echo

BASELINE="$(baseline)"

while IFS= read -r repo; do
  echo "--- ${ORG}/${repo} ---"

  raw="$(api "repos/${ORG}/${repo}/branches/${DEFAULT_BRANCH}/protection" || echo '{}')"
  current="$(echo "${raw}" | normalize_protection)"

  diff="$(jq -n \
  --argjson base "${BASELINE}" \
  --argjson cur "${current}" '
  {
    missing: (
      $base
      | with_entries(
          select(.value != ($cur[.key] // null))
        )
    ),
    extra: (
      $cur
      | with_entries(
          select(.value != ($base[.key] // null))
        )
    )
  }'
)"

  if [[ "$(echo "${diff}" | jq '(.missing|length)+(.extra|length)')" == "0" ]]; then
    echo "[OK] No governance drift"
  else
    echo "[DRIFT] Governance differences detected"
    echo "${diff}" | jq -S .
  fi
  echo
done <<< "$(resolve_repos)"