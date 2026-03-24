# Xentred

**Xentred** is the **canonical governed reference repository** for the Irradi.ato.rs GovOps system.

It is the place where:

- Phase‑2 governance is proven and frozen
- Phase‑3 governance evolution is demonstrated safely
- Governance governs itself under real enforcement
- Auditors, partners, and third parties can inspect *actual behavior*, not promises

Xentred is **not a template** and **not a distribution hub**.  
It is the **reference jurisdiction**.

---

## Role in the Governance System

Xentred sits alongside — but does not replace — the other core components:

| Component | Role |
|---------|-----|
| **rexce** | Canonical governance contract and validator |
| **Xcectua** | Governance orchestration and enforcement rollout |
| **re‑starter.sh** | Deterministic local bootstrap |
| **Xentred** | Governed reference implementation |

Xentred is **itself governed by rexce**.

---

## What Xentred Demonstrates

Xentred shows, in production form:

- A protected default branch
- PR‑only merges
- Exactly **one required check**: `rexce/validate`
- No admin bypass
- Phase‑3 observability (RER Doctor, gov‑diff)
- Governance change proposals with evidence

---

## Governance Enforcement Model

### Canonical Validator — rexce

Governance enforcement is anchored on **rexce**.

rexce provides:

- The governance contract (`rexce-contract.yml|json`)
- The *only* governance validator logic
- A reusable GitHub Actions workflow emitting: rexce/validate

**If `rexce/validate` fails, merge is impossible.**

No other validator may exist.

---

## Governance Adoption

External repositories do **not** copy governance from Xentred.

They adopt governance intentionally by:

1. Reviewing the adoption terms
2. Opening a standardized governance PR in their own repo
3. Merging that PR under local review

The canonical adoption process is documented here:

➡ **GOVERNANCE-ADOPTION.md**

---

## What Xentred Is Not

Xentred is **not**:

- A CI template repo
- A policy copy source
- An onboarding automation target
- A place where other repos’ PRs are merged

Governance flows **by reference and ratification**, not by duplication.

---

## Audit Statement

> **If it isn’t evidenced and validated, it isn’t released.**

Xentred exists so that governance claims can be verified end‑to‑end.

---

## Contact / Authority

Governance authority is held by **Irradi.ato.rs GovOps**.

Operational questions should reference:

- rexce (validation)
- Xcectua (enforcement rollout)
- This repository (reference behavior)

> **CODEOWNERS route review visibility only; governance enforcement is performed exclusively by `rexce/validate` and cannot be overridden by human approval.**

---

**End of README.**