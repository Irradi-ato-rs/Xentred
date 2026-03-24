# Governance Evidence Requirements (Phase‑3)

## Purpose
Define mandatory evidence for all governance changes approved via GCP.

No governance change is valid without evidence.

---

## Evidence Chain (Mandatory)

Each governance change must produce:

1. **Approved GCP**
   - GCP ID
   - Approval date
   - Approvers

2. **Baseline Diff (Before)**
   - Output from Governance Diff Engine
   - Captured before change is applied

3. **Change Application Record**
   - Description of how the change was applied
   - Manual steps or script version used

4. **Baseline Diff (After)**
   - Output from Governance Diff Engine
   - Must show:
     - No Phase‑2 violations
     - Expected diffs resolved

5. **Evidence Bundle**
   - Script SHA256 (if applicable)
   - Workflow SHA256 (if applicable)
   - GitHub run ID (if applicable)
   - Timestamps
   - Affected repositories

---

## Evidence Handling Rules

- Evidence is generated **locally by default**
- Evidence is **never auto‑published**
- Evidence must be retained for audit
- Evidence may be attached to a PR or archived externally

---

## Validation Rules

- Missing evidence invalidates the change
- Evidence must be reproducible
- Evidence must be attributable to a specific GCP

---

## Phase‑2 Boundary

Evidence requirements must not be used to weaken or bypass Phase‑2 invariants.
