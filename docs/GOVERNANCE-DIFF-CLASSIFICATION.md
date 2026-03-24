# Governance Diff Classification (Phase‑3 v0.1)

## Purpose
Classify governance differences detected by the Governance Diff Engine.

Classification is **read‑only** and does not modify enforcement.

---

## Classification Levels

### ✅ ALLOWED
Benign differences that do not affect Phase‑2 invariants.

Examples:
- Fully compliant repositories
- Archived repositories
- Explicitly excluded repositories

Action: No action required.

---

### ⚠️ WARNING
Differences that may indicate drift, incomplete rollout, or transitional state.

Examples:
- `dismiss_stale_reviews` disabled
- Repo newly created and not yet governed
- Temporary drift during approved rollout window

Action: Review recommended. GCP optional.

---

### ❌ VIOLATION
Differences that break Phase‑2 invariants.

Examples:
- Missing `rexce/validate`
- Extra required status checks
- PRs not required
- Strict mode disabled
- Admin enforcement disabled

Action: Remediation required via Governance Change Proposal (GCP).

---

## Enforcement Rules
- Violations must not be ignored
- Violations require explicit remediation
- Warnings require human acknowledgement
- Allowed diffs require no action

---

## Phase‑2 Boundary
This classification must not be used to weaken Phase‑2 invariants.