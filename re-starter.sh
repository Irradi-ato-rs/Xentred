#!/usr/bin/env bash
#
# re-starter.sh (c) Irradi.ato.rs\r
# Fully Phase‑4 compliant. Payload will be embedded by assembler.
#
set -euo pipefail

# Payload SHA placeholder — assembler will replace this
RER_PAYLOAD_SHA256="9bfa8786c6a62958d1bcbe9faa8a1e515c56a89996088d2c857fc1572e71d18f"

# Canonical Xentred source
XENTRED_REPO="Irradi-ato-rs/Xentred"
XENTRED_REF="main"
XENTRED_PATH="circuits/rer"

phase(){ echo; echo "========== [RER] $* ==========" >&2; }
note(){ echo "[RER] $*" >&2; }
die(){ echo "[RER][ERROR] $*" >&2; exit 1; }

need_cmd(){ command -v "$1" >/dev/null 2>&1 || die "Missing cmd: $1"; }

sha256_file(){
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# ==============================================================================
# Extract embedded payload (assembler inserts after marker)
# ==============================================================================
extract_payload(){
  local out="$1"
  awk 'BEGIN{m="__RER_PAYLOAD__"} $0==m{found=1;next} found{print}' "$0" \
    | base64 -d \
    > "$out"
}

verify_payload(){
  phase "Payload integrity triad"
  local tmp; tmp="$(mktemp -d)"
  local tarball="$tmp/payload.tar.gz"
  extract_payload "$tarball"
  local calc; calc="$(sha256_file "$tarball")"
  echo "expected=$RER_PAYLOAD_SHA256"
  echo "actual=$calc"
  [[ "$calc" = "$RER_PAYLOAD_SHA256" ]] || die "Payload SHA mismatch"
}

###############################################################################
# SECTION — FETCH CANONICAL RER CIRCUIT (FIXED SPARSE CHECKOUT)
###############################################################################

fetch_rer_circuit() {
  phase "Fetch canonical RER circuit from Xentred"

  need_cmd git

  local TMP
  TMP="$(mktemp -d)"

  git clone --depth=1 --filter=blob:none --sparse \
    "https://github.com/${XENTRED_REPO}.git" "$TMP"

  (
    cd "$TMP"
    git sparse-checkout init --cone
    git sparse-checkout set "${XENTRED_PATH}"
  )

  mkdir -p rer
  cp -R "$TMP/${XENTRED_PATH}/." rer/

  # Generate lockfile
  cat > rer/rer.lock.yml <<EOF
rer:
  repo: $(basename "$(pwd)")
  ref: main
  schema: v1
EOF
}

apply_circuit(){
  phase "Applying canonical RER circuit"
  fetch_rer_circuit
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "RER bootstrap: canonical circuit install"
  fi
}

main(){
  verify_payload
  apply_circuit
  phase "DONE"
  note "RER adoption complete"
}

main "$@"

# ========================================================================
# PAYLOAD MARKER — assembler appends Base64 tarball AFTER THIS LINE
# ========================================================================
__RER_PAYLOAD__
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

