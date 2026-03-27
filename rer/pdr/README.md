# PDR — Proof of Deterministic Release
## Canonical Evidence Boundary (Phase‑2 Frozen)

The PDR boundary defines the set of evidence directories that must exist for any
release validated under the RER governance circuit. These paths are **frozen**
during Phase‑2 and may only change via an approved Governance Change Proposal
(GCP) validated by rexce.

The PDR boundary is declared in:
pdr/evidence-dirs.txt

This manifest establishes a deterministic, non-inferable, non-scannable
evidence scope for all release validation.

---

## ✅ Required Evidence Directories


evidence/release
evidence/sbom
evidence/provenance
evidence/inventory

### `evidence/release/`  
Release metadata, integrity attestations, checksums, and artifacts.

### `evidence/sbom/`  
Canonical SBOMs in SPDX and CycloneDX formats.

### `evidence/provenance/`  
Build provenance, supply-chain attestations, and SLSA‑style integrity proofs.

### `evidence/inventory/`  
Artifact, file‑inventory, and dependency manifests.

---

## ✅ Governance Gate Behavior  
The workflow:


workflows/rer-governance-gate.yml

performs:

1. **Manifest check**  
   Ensures `pdr/evidence-dirs.txt` exists.

2. **Directory existence check**  
   All required directories must exist, even if empty.

3. **Deterministic hashing**  
   SHA256 hashing across all directories listed in the manifest.

4. **PDR bundle preparation (Phase‑4)**  
   Downstream automation (Xcectua) uses these hashes for:
   - governance state
   - propagation waves
   - evidence bundle generation

---

## ✅ Phase Guarantees

### Phase‑2 (Frozen)  
- Evidence boundary fixed  
- Missing directories = hard fail  

### Phase‑3 (Evolution)  
- Classification + GCP governance  
- No boundary drift  

### Phase‑4 (Automation)  
- Deterministic evidence processing  
- Org‑wide state propagation  

---

Do not modify any part of the PDR boundary without a GCP.