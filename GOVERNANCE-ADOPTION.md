# Governance Adoption

> **Canonical entry point for adopting Irradi.ato.rs GovOps governance**

This document defines **how an external repository or organization may intentionally adopt governance**
provided by the **Irradi.ato.rs GovOps system**, implemented through **rexce**, **Xcectua**, and the
**Xentred** reference model.

Adoption is **explicit, opt‑in, auditable, and reversible**.

---

## 1. What This Is

Adopting governance means that your repository:

- Accepts **rexce** as the **canonical governance validator**
- Accepts **GitHub‑native enforcement** (branch protection + required checks)
- Accepts that governance logic **does not live in your repo**
- Accepts that governance evolution follows a **formal, evidence‑backed process**

This is **governance as a contract**, not a template or best‑practice guide.

---

## 2. Governance Authority

Governance authority is held by:

**Irradi.ato.rs GovOps**

- Canonical validator: **rexce**
- Governance orchestrator: **Xcectua**
- Reference implementation & evolution ground: **Xentred**

Your repository **consumes governance**; it does not redefine it.

---

## 3. What Is Enforced vs Observed

### ✅ Enforced (Phase‑2, Frozen)

- Single required status check: `rexce/validate`
- No admin bypass
- No duplicate or shadow validators
- Deterministic GitHub‑native enforcement only

Failure of `rexce/validate` **blocks merge**.

### 👁 Observed Only (Phase‑3)

- Governance diffs
- RER Doctor classifications (OK / WARNING / VIOLATION)
- Issues and notifications

Observed signals **never block merges**.

---

## 4. How Adoption Works (Canonical Path)

Adoption occurs through **one explicit act**:

> **Opening and merging a standardized governance PR in your own repository.**

This PR:

- Adds the canonical `rexce/validate` workflow (SHA‑pinned)
- Adds non‑blocking Phase‑3 observability tooling
- Adds governance documentation
- Does **not** auto‑apply enforcement

The PR is reviewed and merged **by your repo maintainers**.

This merge is the **ratification event**.

---

## 5. The Repo‑Ready Governance PR

The repo‑ready PR is:

- Repo‑agnostic
- Identical across all adopting repos
- Reviewed locally
- Auditable
- Reversible

It is **never merged in Xentred**.

---

## 6. Applying Enforcement

After adoption PR merge, enforcement is applied **separately** via **Xcectua**:

- Branch protection rules
- Required check registration
- Free‑tier fallback handling

Enforcement is explicit and deterministic.

---

## 7. Governance Evolution (Phase‑3)

All governance evolution requires:

- Governance Change Proposal (GCP)
- Before/after diffs
- Evidence bundle or trace
- Review under rexce validation

Governance **governs itself**.

---

## 8. Exit / Revocation

A repository may exit governance by:

1. Opening a PR removing governance artifacts
2. Classifying the change as governance removal
3. Providing rationale and evidence
4. Merging under existing enforcement

Exit is **visible and auditable**.

---

## 9. Audit Statement

> **If it isn’t evidenced and validated, it isn’t released.**

---

**End of document.**