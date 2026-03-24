#!/usr/bin/env bash
# rer-free-fallback-rollout.sh (v0.6)
# Phase-2: Classic branch protection fallback enforcing a single canonical check (rexce/validate).
# Deterministic, idempotent, evidence-emitting (local). No auto-commit/publish.

set -euo pipefail

# ---------- Inputs ----------
ORG="${ORG:-}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
TAG_PATTERNS="${TAG_PATTERNS:-v*.*.*}"
REPOS_ALLOWLIST="${REPOS_ALLOWLIST:-}"
DRY_RUN="${DRY_RUN:-true}"
GH_TOKEN="${GH_TOKEN:-}"
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"

REQUIRED_CHECK="rexce/validate"
REQUIRED_REVIEWS=1
DISMISS_STALE_REVIEWS=true
ENFORCE_ADMINS=true

# Evidence dir (local-only, not auto-committed)
EVIDENCE_DIR="${GITHUB_WORKSPACE:-.}/.evidence/rer-free-fallback/v0.6/${ORG}"
mkdir -p "${EVIDENCE_DIR}"

# ---------- Guards ----------
req() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 not found"; exit 2; }; }
req curl
req jq

if [[ -z "${ORG}" ]]; then
  echo "ERROR: ORG is required"; exit 2
fi
if [[ -z "${GH_TOKEN}" ]]; then
  echo "ERROR: GH_TOKEN is required"; exit 2
fi

# ---------- Helpers ----------
api() {
  # Usage: api METHOD PATH [DATA_JSON]
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"

  local url="${GITHUB_API_URL%/}/${path#'/'}"
  local hdr=(-H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json")

  if [[ -n "${data}" ]]; then
    curl -sS -X "${method}" "${url}" "${hdr[@]}" -d "${data}"
  else
    curl -sS -X "${method}" "${url}" "${hdr[@]}"
  fi
}

api_status() {
  # Same as api but include headers for rate-limit diagnostics
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"

  local url="${GITHUB_API_URL%/}/${path#'/'}"
  local hdr=(-H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json")

  if [[ -n "${data}" ]]; then
    curl -sSI -X "${method}" "${url}" "${hdr[@]}" -d "${data}"
  else
    curl -sSI -X "${method}" "${url}" "${hdr[@]}"
  fi
}

json_min() {
  # Minimal normalize a JSON blob (order-insensitive)
  jq -S .
}

split_list() {
  # Split space- or comma-separated list into newline-separated items
  tr ', ' '\n' | sed '/^\s*$/d'
}

# ---------- Repo enumeration ----------
get_all_repos() {
  # List all non-archived repos in org (visibility: all)
  local page=1
  while :; do
    resp="$(api GET "/orgs/${ORG}/repos?per_page=100&page=${page}&type=all&sort=full_name&direction=asc")"
    count="$(jq 'length' <<<"${resp}")"
    jq -r '.[] | select(.archived==false) | .name' <<<"${resp}"
    [[ "${count}" -lt 100 ]] && break
    page=$((page+1))
  done
}

resolve_target_repos() {
  if [[ -n "${REPOS_ALLOWLIST}" ]]; then
    echo "${REPOS_ALLOWLIST}" | split_list | sed 's#^.*/##' | sort -u
  else
    get_all_repos | sort -u
  fi
}

# ---------- Branch protection desired state ----------
desired_protection_body() {
  # Build desired classic protection JSON
  jq -n \
    --arg check "${REQUIRED_CHECK}" \
    --argjson strict true \
    --argjson admins ${ENFORCE_ADMINS} \
    --argjson dismiss ${DISMISS_STALE_REVIEWS} \
    --argjson count ${REQUIRED_REVIEWS} \
    '{
      required_status_checks: { strict: $strict, contexts: [$check] },
      enforce_admins: $admins,
      required_pull_request_reviews: {
        required_approving_review_count: $count,
        dismiss_stale_reviews: $dismiss
      },
      restrictions: null
    }'
}

# ---------- Current state fetch ----------
get_protection() {
  local repo="$1"
  api GET "/repos/${ORG}/${repo}/branches/${DEFAULT_BRANCH}/protection"
}

# ---------- Apply branch protection ----------
apply_protection() {
  local repo="$1"
  local body="$2"

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "DRY-RUN: Would PUT classic protection for ${ORG}/${repo}@${DEFAULT_BRANCH}"
    echo "${body}" | json_min
    return 0
  fi

  echo "APPLY: PUT protection for ${ORG}/${repo}@${DEFAULT_BRANCH}"
  api_status PUT "/repos/${ORG}/${repo}/branches/${DEFAULT_BRANCH}/protection" "${body}" >/dev/null || true
  resp="$(api PUT "/repos/${ORG}/${repo}/branches/${DEFAULT_BRANCH}/protection" "${body}")"
  # Some orgs/repo settings can return partial objects; we do not fail on structure variance.
  echo "${resp}" | jq -S '{
    required_status_checks: { strict: .required_status_checks.strict, contexts: .required_status_checks.contexts },
    enforce_admins: .enforce_admins.enabled,
    required_pull_request_reviews: {
      required_approving_review_count: .required_pull_request_reviews.required_approving_review_count,
      dismiss_stale_reviews: .required_pull_request_reviews.dismiss_stale_reviews
    }
  }' 2>/dev/null || true
}

# ---------- Tag protection (best-effort on Free) ----------
protect_tags() {
  local repo="$1"
  local patterns_csv="$2"

  IFS=',' read -r -a patterns <<< "${patterns_csv}"
  for pat in "${patterns[@]}"; do
    pat="$(echo "${pat}" | xargs)"
    [[ -z "${pat}" ]] && continue
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "DRY-RUN: Would create tag protection for ${ORG}/${repo} pattern='${pat}' (best-effort on Free)"
      continue
    fi

    # Classic Protected Tags API (returns 404 on Free/unsupported)
    status="$(api_status POST "/repos/${ORG}/${repo}/tags/protection" "$(jq -n --arg pattern "${pat}" '{pattern:$pattern}')" | head -n 1 || true)"
    if grep -q "404" <<<"${status}"; then
      echo "NOTE: Tag protection not supported here (404 expected on Free) repo=${ORG}/${repo} pattern='${pat}'"
      continue
    fi
    # Attempt actual call (ignore non-200)
    resp="$(api POST "/repos/${ORG}/${repo}/tags/protection" "$(jq -n --arg pattern "${pat}" '{pattern:$pattern}')" || true)"
    echo "Tag protection response (non-fatal): ${resp}" | sed -e 's/["{}]//g'
  done
}

# ---------- Diff & Evidence ----------
emit_evidence() {
  local repo="$1" before="$2" desired="$3" after="$4"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  jq -n --arg org "${ORG}" --arg repo "${repo}" --arg branch "${DEFAULT_BRANCH}" \
        --arg ts "${ts}" \
        --arg required_check "${REQUIRED_CHECK}" \
        --arg dry_run "${DRY_RUN}" \
        --argjson before "${before}" --argjson desired "${desired}" --argjson after "${after}" \
        '{
          org:$org, repo:$repo, branch:$branch, ts:$ts,
          required_check:$required_check, dry_run: $dry_run,
          before:$before, desired:$desired, after:$after
        }' | tee "${EVIDENCE_DIR}/${repo}.json" >/dev/null
}

normalize_protection_view() {
  # Normalize only the fields we care about (ignore unrelated policies)
  jq -S '{
    required_status_checks: ( .required_status_checks | { strict, contexts } ),
    enforce_admins: ( if .enforce_admins==true or .enforce_admins.enabled==true then true else false end ),
    required_pull_request_reviews: (
      .required_pull_request_reviews as $r
      | if $r==null then null else {
          required_approving_review_count: $r.required_approving_review_count,
          dismiss_stale_reviews: $r.dismiss_stale_reviews
        } end
    )
  }'
}

protection_equal() {
  local norm_before="$1" norm_desired="$2"
  diff=$(jq -n --argjson a "${norm_before}" --argjson b "${norm_desired}" '$a == $b')
  [[ "${diff}" == "true" ]]
}

# ---------- Main ----------
main() {
  echo "=== RER Free Fallback Rollout v0.6 ==="
  echo "Org=${ORG} Branch=${DEFAULT_BRANCH} DryRun=${DRY_RUN} RequiredCheck=${REQUIRED_CHECK}"
  echo "EvidenceDir=${EVIDENCE_DIR}"
  echo

  local repos
  repos="$(resolve_target_repos)"
  if [[ -z "${repos}" ]]; then
    echo "No target repositories resolved. Exiting."; exit 0
  fi

  local desired
  desired="$(desired_protection_body)"

  while IFS= read -r repo; do
    [[ -z "${repo}" ]] && continue
    echo "--- Processing ${ORG}/${repo} ---"

    # Fetch current protection (may be 404 if unset)
    current_raw="$(api GET "/repos/${ORG}/${repo}/branches/${DEFAULT_BRANCH}/protection" || true)"
    if jq -e '.message=="Branch not protected"' <<<"${current_raw}" >/dev/null 2>&1; then
      current_raw="{}"
    fi
    norm_before="$(echo "${current_raw}" | normalize_protection_view || echo '{}')"
    norm_desired="$(echo "${desired}" | normalize_protection_view)"

    echo "Current (normalized):"
    echo "${norm_before}" | json_min
    echo "Desired:"
    echo "${norm_desired}" | json_min

    if protection_equal "${norm_before}" "${norm_desired}"; then
      echo "No change needed (idempotent)."
      after="${current_raw}"
    else
      echo "Change required."
      applied="$(apply_protection "${repo}" "${desired}")"
      after="${applied:-"${current_raw}"}"
    fi

    # Tag protection best-effort
    protect_tags "${repo}" "${TAG_PATTERNS}"

    # Evidence (before/desired/after)
    emit_evidence "${repo}" "${norm_before}" "${norm_desired}" "$(echo "${after}" | normalize_protection_view || echo '{}')"
    echo
  done <<< "${repos}"
}

main "$@"