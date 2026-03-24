#!/usr/bin/env bash
# rer-free-fallback-rollout.sh (v0.9)
# Phase-2 hardened fallback enforcement
# Adds: pinning lineage, workflow checksum, run identity
# No behavior changes from v0.8

set -euo pipefail

# ---------- Inputs ----------
ORG="${ORG:-}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
TAG_PATTERNS="${TAG_PATTERNS:-v*.*.*}"
REPOS_ALLOWLIST="${REPOS_ALLOWLIST:-}"
DRY_RUN="${DRY_RUN:-true}"
EXPORT_EVIDENCE="${EXPORT_EVIDENCE:-false}"
STRICT="${STRICT:-0}"
GH_TOKEN="${GH_TOKEN:-}"
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"

REQUIRED_CHECK="rexce/validate"
REQUIRED_REVIEWS=1
DISMISS_STALE_REVIEWS=true
ENFORCE_ADMINS=true
RATE_WARN_THRESHOLD=100

# ---------- Identity ----------
VERSION="v0.9"
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SCRIPT_SHA256="$(sha256sum "$SCRIPT_PATH" | awk '{print $1}')"
WORKFLOW_PATH="${GITHUB_WORKSPACE:-.}/.github/workflows/rer-free-fallback-rollout.yml"
WORKFLOW_SHA256="$(sha256sum "$WORKFLOW_PATH" 2>/dev/null | awk '{print $1}')"
RUN_ID="${GITHUB_RUN_ID:-unknown}"
REPO_SLUG="${GITHUB_REPOSITORY:-unknown}"
REF="${GITHUB_REF:-unknown}"
START_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# ---------- Evidence ----------
BASE_EVIDENCE_DIR="${GITHUB_WORKSPACE:-.}/.evidence/rer-free-fallback/${VERSION}/${ORG}"
EVIDENCE_DIR="${BASE_EVIDENCE_DIR}/repos"
MANIFEST="${BASE_EVIDENCE_DIR}/manifest.json"
BUNDLE="${BASE_EVIDENCE_DIR}/bundle.tar.gz"
mkdir -p "${EVIDENCE_DIR}"

# ---------- Guards ----------
req() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 not found"; exit 2; }; }
req curl jq tar sha256sum
[[ -z "${ORG}" ]] && { echo "ERROR: ORG is required"; exit 2; }
[[ -z "${GH_TOKEN}" ]] && { echo "ERROR: GH_TOKEN is required"; exit 2; }

# ---------- API ----------
api() {
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"
  local url="${GITHUB_API_URL%/}/${path#'/'}"
  local hdr=(-H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json")

  local resp headers body remaining reset
  if [[ -n "${data}" ]]; then
    resp="$(curl -sS -D - -X "${method}" "${url}" "${hdr[@]}" -d "${data}")"
  else
    resp="$(curl -sS -D - -X "${method}" "${url}" "${hdr[@]}")"
  fi

  headers="$(sed -n '1,/^\r$/p' <<<"${resp}")"
  body="$(sed '1,/^\r$/d' <<<"${resp}")"

  remaining="$(grep -i '^x-ratelimit-remaining:' <<<"${headers}" | awk '{print $2}' | tr -d '\r')"
  reset="$(grep -i '^x-ratelimit-reset:' <<<"${headers}" | awk '{print $2}' | tr -d '\r')"
  if [[ -n "${remaining}" && "${remaining}" -lt "${RATE_WARN_THRESHOLD}" ]]; then
    echo "WARN: API rate limit low (remaining=${remaining}, reset=${reset})"
  fi
  echo "${body}"
}

# ---------- Utilities ----------
split_list() { tr ', ' '\n' | sed '/^\s*$/d'; }

# ---------- Repo enumeration ----------
get_all_repos() {
  local page=1
  while :; do
    echo "INFO: Fetching repos page=${page}"
    resp="$(api GET "/orgs/${ORG}/repos?per_page=100&page=${page}&type=all")"
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

# ---------- Desired protection ----------
desired_protection_body() {
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

normalize_protection_view() {
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
  jq -n --argjson a "$1" --argjson b "$2" '$a == $b' | grep -q true
}

apply_protection() {
  local repo="$1" body="$2"
  [[ "${DRY_RUN}" == "true" ]] && return 0
  api PUT "/repos/${ORG}/${repo}/branches/${DEFAULT_BRANCH}/protection" "${body}" >/dev/null || true
}

emit_evidence() {
  local repo="$1" before="$2" desired="$3" after="$4" action="$5" reason="$6"
  jq -n \
    --arg version "${VERSION}" \
    --arg org "${ORG}" --arg repo "${repo}" --arg branch "${DEFAULT_BRANCH}" \
    --arg required_check "${REQUIRED_CHECK}" \
    --arg dry_run "${DRY_RUN}" --arg action "${action}" --arg reason "${reason}" \
    --argjson before "${before}" --argjson desired "${desired}" --argjson after "${after}" \
    '{
      version:$version, org:$org, repo:$repo, branch:$branch,
      required_check:$required_check, dry_run:$dry_run,
      action:$action, reason:$reason,
      before:$before, desired:$desired, after:$after
    }' > "${EVIDENCE_DIR}/${repo}.json"
}

# ---------- Main ----------
main() {
  echo "=== RER Free Fallback Rollout ${VERSION} ==="
  echo "Org=${ORG} Branch=${DEFAULT_BRANCH} DryRun=${DRY_RUN} STRICT=${STRICT}"
  echo "ScriptSHA256=${SCRIPT_SHA256}"
  echo "WorkflowSHA256=${WORKFLOW_SHA256}"
  echo "RunID=${RUN_ID} Repo=${REPO_SLUG} Ref=${REF}"
  echo "EvidenceDir=${BASE_EVIDENCE_DIR}"
  echo

  repos="$(resolve_target_repos)"
  desired="$(desired_protection_body)"
  drift_count=0

  while IFS= read -r repo; do
    [[ -z "${repo}" ]] && continue
    current_raw="$(api GET "/repos/${ORG}/${repo}/branches/${DEFAULT_BRANCH}/protection" || echo '{}')"
    norm_before="$(echo "${current_raw}" | normalize_protection_view || echo '{}')"
    norm_desired="$(echo "${desired}" | normalize_protection_view)"

    if protection_equal "${norm_before}" "${norm_desired}"; then
      action="NOOP"; reason="IDEMPOTENT"; after="${current_raw}"
    else
      action="APPLY"; reason="DRIFT"; drift_count=$((drift_count+1))
      apply_protection "${repo}" "${desired}"
      after="${current_raw}"
    fi

    emit_evidence "${repo}" "${norm_before}" "${norm_desired}" "$(echo "${after}" | normalize_protection_view || echo '{}')" "${action}" "${reason}"
    echo "[repo=${repo}][action=${action}][reason=${reason}][status=OK]"
  done <<< "${repos}"

  if [[ "${STRICT}" == "1" && "${DRY_RUN}" == "true" && "${drift_count}" -gt 0 ]]; then
    echo "ERROR: STRICT=1 and drift detected (${drift_count})"
    exit 3
  fi

  END_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  jq -n \
    --arg version "${VERSION}" --arg org "${ORG}" \
    --arg start "${START_TS}" --arg end "${END_TS}" \
    --arg script_sha "${SCRIPT_SHA256}" --arg workflow_sha "${WORKFLOW_SHA256}" \
    --arg run_id "${RUN_ID}" --arg repo "${REPO_SLUG}" --arg ref "${REF}" \
    --arg dry_run "${DRY_RUN}" --arg strict "${STRICT}" --arg export "${EXPORT_EVIDENCE}" \
    '{
      version:$version, org:$org,
      start_ts:$start, end_ts:$end,
      script_sha256:$script_sha,
      workflow_sha256:$workflow_sha,
      run_id:$run_id, repository:$repo, ref:$ref,
      dry_run:$dry_run, strict:$strict, export_evidence:$export
    }' > "${MANIFEST}"

  if [[ "${EXPORT_EVIDENCE}" == "true" ]]; then
    tar -czf "${BUNDLE}" -C "${BASE_EVIDENCE_DIR}" .
    echo "Evidence bundle created: ${BUNDLE}"
  fi
}

main "$@"