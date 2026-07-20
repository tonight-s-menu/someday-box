#!/bin/sh
# Audit only reviewed proof bytes; it never generates or modifies assets.
set -eu
export PYTHONDONTWRITEBYTECODE=1
export PYTHONHASHSEED=0
export PYTHONNOUSERSITE=1
export PYTHONPATH=
export PYTHONHOME=
export PYTHONUSERBASE=

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
/usr/bin/python3 -B "$repo_root/scripts/audit-core-box-proof.py"
/usr/bin/usdchecker --arkit --strict "$repo_root/SomedayBoxTests/Fixtures/CoreBoxProofFull.usdz"
/usr/bin/usdchecker --arkit --strict "$repo_root/SomedayBoxTests/Fixtures/CoreBoxProofLite.usdz"
