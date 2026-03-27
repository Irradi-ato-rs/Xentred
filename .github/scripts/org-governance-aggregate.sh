#!/usr/bin/env bash
# org-governance-aggregate.sh (v0.2)
# Org-wide governance health aggregation (read-only)
# Wraps RER Doctor per repo and aggregates results.
#
# Phase‑4 Safe • Read-Only • Deterministic • Operator-Grade

set -euo pipefail

ORG="${ORG:-}"
GH_TOKEN="${GH_TOKEN:-}"
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"

[[ -z "${ORG}" ]] && { echo "ERROR: ORG is required"; exit 2; }
[[ -z "${GH_TOKEN}" ]] && { echo "ERROR: GH_TOKEN is required"; exit 2; }

command -v curl >/dev/null || { echo "ERROR: curl not found"; exit 2; }
command -v jq   >/dev/null || { echo "ERROR: jq not found"; exit 2; }

api() {
  curl -sS \
    -H "Authorization: Bearer ${GH_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "${GITHUB_API_URL%/}/$1"
}

echo "=== Org Governance Aggregation v0.2 ==="
echo "ORG=${ORG}"
echo

# -------------------------------------------------------------------
# ✅ Fetch all non-archived repos in the org
# -------------------------------------------------------------------
repos="$(api "orgs/${ORG}/repos?per_page=100&type=all" \
  | jq -r '.[] | select(.archived==false) | .name')"

ok=0
warn=0
violation=0
details=()

# -------------------------------------------------------------------
# ✅ Aggregate each repo using RER Doctor (read-only)
# -------------------------------------------------------------------
for repo in ${repos}; do
  echo "--- Checking ${ORG}/${repo} ---"

  export ORG
  export GH_TOKEN
  export REPOS_ALLOWLIST="${repo}"
  export GITHUB_REPOSITORY="${ORG}/${repo}"

  #
  # ✅ Critical Fix:
  # Protect rer-doctor invocation from set -e, because rer-doctor
  # intentionally returns non-zero codes (10 = WARNING, 20 = VIOLATION).
  #
  set +e
  bash .github/scripts/rer-doctor.sh >/dev/null 2>&1
  rc=$?
  set -e

  case "${rc}" in
    0)
      status="OK"
      ok=$((ok+1))
      ;;
    10)
      status="WARNING"
      warn=$((warn+1))
      ;;
    20)
      status="VIOLATION"
      violation=$((violation+1))
      ;;
    *)
      status="ERROR"
      ;;
  esac

  details+=("$(jq -n --arg repo "${repo}" --arg status "${status}" '{repo:$repo,status:$status}')")
done

# -------------------------------------------------------------------
# ✅ Build JSON summary
# -------------------------------------------------------------------
summary="$(jq -n \
  --arg org "${ORG}" \
  --argjson ok "${ok}" \
  --argjson warn "${warn}" \
  --argjson violation "${violation}" \
  --argjson repos "[${details[*]}]" \
  '{
    org:$org,
    summary:{ok:$ok, warning:$warn, violation:$violation},
    repos:$repos
  }')"

echo
echo "=== Org Governance Summary ==="
echo "${summary}" | jq -r '
  "OK: \(.summary.ok)\nWARNING: \(.summary.warning)\nVIOLATION: \(.summary.violation)"
'

echo
echo "JSON Summary:"
echo "${summary}" | jq -S .

# -------------------------------------------------------------------
# ✅ Phase‑4 Correct Exit Behavior
# WARNINGs do NOT cause non-zero exit. Only VIOLATION does.
# -------------------------------------------------------------------
[[ "${violation}" -gt 0 ]] && exit 20 || exit 0