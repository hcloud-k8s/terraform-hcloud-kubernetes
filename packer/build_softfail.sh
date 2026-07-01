#!/usr/bin/env bash
#
# Wrapper around `packer build` for the ARM64 Talos snapshot.
#
# Hetzner CAX (ARM64) servers are frequently out of stock. The snapshot can only
# be produced by snapshotting a running CAX server, so when no CAX capacity is
# available the Packer build fails. Without this wrapper that failure aborts the
# whole `terraform apply`, even when a usable ARM64 snapshot already exists in
# the account.
#
# Behaviour:
#   - Run `packer build "$@"`, teeing combined output to a temp log.
#   - On a Hetzner "no capacity" failure (API error code `resource_unavailable`),
#     print a warning and exit 0 so the apply continues and reuses the existing
#     snapshot (resolved via a version-agnostic image selector in image.tf).
#   - On any other failure, propagate Packer's original exit code so genuine
#     errors still fail the apply.
#
# Usage: bash build_softfail.sh <packer build args...>

set -uo pipefail

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

packer build "$@" 2>&1 | tee "$log"
status="${PIPESTATUS[0]}"

if [ "$status" -ne 0 ]; then
  if grep -qiE 'resource_unavailable' "$log"; then
    echo "WARN: Hetzner reports no ARM64 (CAX) capacity for the Packer builder." >&2
    echo "WARN: Skipping ARM64 snapshot (re)build; reusing the existing snapshot." >&2
    exit 0
  fi
  exit "$status"
fi
