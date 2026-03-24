# Security Policy

This document defines **security reporting and handling** for **Xentred**, the governed
reference repository of the Irradi.ato.rs GovOps system.

Security issues are **distinct** from governance, policy, or validation outcomes.

---

## 1. Scope

This policy applies to:

- The Xentred repository
- GitHub Actions workflows
- Automation and scripts
- Use of external reusable workflows

It does **not** redefine governance rules or enforcement behavior.

---

## 2. What Is a Security Issue

Security issues include:

- Credential or secret exposure
- Unauthorized access paths
- Privilege escalation or permission bypass
- Supply‑chain compromise
- Malicious code execution in CI/CD
- Vulnerabilities in GitHub Actions usage

---

## 3. What Is *Not* a Security Issue

The following are **not** security issues:

- `rexce/validate` failures
- Governance violations or warnings
- RER Doctor findings
- Governance drift reports
- Policy disagreements
- Phase‑3 governance proposals

These are **governance matters**, not vulnerabilities.

---

## 4. Governance Enforcement Clarification

Governance enforcement is performed **exclusively** by **rexce**.

rexce emits the required check:rexce/validate

A failure is an **intentional control mechanism**, not a defect or incident.

---

## 5. Reporting a Security Issue

Security issues must be reported **privately** via:

- GitHub Private Security Advisories (if enabled)
- Designated security contact (out‑of‑band)

Do **not** open public issues for active vulnerabilities.

---

## 6. Responsible Disclosure

Please allow time for:

- Triage
- Impact assessment
- Mitigation
- Coordinated disclosure

---

## 7. Relationship to Governance

Security remediation does **not** bypass governance.

Any fix affecting governance must:

- Be proposed via PR
- Pass `rexce/validate`
- Respect Phase‑2 invariants
- Follow Phase‑3 evidence requirements

---

**End of SECURITY policy.**