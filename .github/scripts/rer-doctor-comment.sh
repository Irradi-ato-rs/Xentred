#!/usr/bin/env bash
# rer-doctor-comment.sh
# Posts RER Doctor summary as a PR comment (read-only).

set -euo pipefail

[[ -z "${GITHUB_TOKEN:-}" ]] && { echo "ERROR: GITHUB_TOKEN required"; exit 2; }
[[ -z "${PR_NUMBER:-}" ]] && { echo "ERROR: PR_NUMBER required"; exit 2; }
[[ -z "${REPO:-}" ]] && { echo "ERROR: REPO required"; exit 2; }

BODY_FILE="${1:-}"
[[ -z "$BODY_FILE" || ! -f "$BODY_FILE" ]] && { echo "ERROR: comment body file missing"; exit 2; }

API="https://api.github.com"
AUTH="-H Authorization: Bearer ${GITHUB_TOKEN}"
JSON="-H Content-Type: application/json"

MARKER="<!-- RER-DOCTOR -->"

# Find existing comment
COMMENT_ID="$(curl -sS $AUTH \
  "${API}/repos/${REPO}/issues/${PR_NUMBER}/comments" |
  jq -r ".[] | select(.body | contains(\"${MARKER}\")) | .id" | head -n1)"

BODY="$(jq -Rs --arg m "$MARKER" '{body: ($m + "\n" + .)}' < "$BODY_FILE")"

if [[ -n "$COMMENT_ID" ]]; then
  echo "Updating existing RER Doctor comment"
  curl -sS -X PATCH $AUTH $JSON \
    "${API}/repos/${REPO}/issues/comments/${COMMENT_ID}" \
    -d "$BODY" >/dev/null
else
  echo "Creating new RER Doctor comment"
  curl -sS -X POST $AUTH $JSON \
    "${API}/repos/${REPO}/issues/${PR_NUMBER}/comments" \
    -d "$BODY" >/dev/null
fi