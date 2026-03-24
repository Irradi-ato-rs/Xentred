# Phase‑2 Governance Invariants (v1.0)

## Status
**FROZEN** — Any change requires explicit Phase‑3 approval.

## Canonical Validator
- The only canonical validator is **rexce**
- Validator logic must never be duplicated
- Canonical required status check: rexce/validate

## Enforcement Model
- Enforcement uses **GitHub native branch protection**
- Org rulesets are used when available
- GitHub Free uses **classic branch protection fallback**

## Branch Protection Invariants
Protected default branch (`main`) MUST enforce:
- Pull requests required
- Exactly **1** approving review
- Required status checks:
- `rexce/validate` (only)
- Require branches to be up to date
- Admins enforced (no bypass)

## Workflow Separation
- **Installer**: `rer-free-fallback-rollout`
- Applies branch protection only
- Never emits PR checks
- **Validator**: `rexce`
- Emits `rexce/validate`
- Never modifies branch protection

## Evidence Model
- Evidence is generated **locally by default**
- Evidence is never auto‑published
- Export requires explicit operator intent
- Evidence must include:
- Script SHA256
- Workflow SHA256
- Run ID
- Inputs

## Non‑Negotiables
- No direct pushes to protected branches
- No silent auto‑fixes
- No weakening of required checks
- No admin bypass
- No fork‑only governance PRs (same‑repo preferred)

## Phase Boundary
- Phase‑2 is complete at v1.0
- Any changes beyond this point belong to Phase‑3