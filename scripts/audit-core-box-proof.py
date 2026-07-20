"""Fail-closed audit for the verification-only Core Box proof bundle."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "SomedayBoxTests/Fixtures"
GENERATED = ROOT / "SomedayBoxTests/Generated/CoreBoxProofIdentity.generated.swift"
PROJECT = ROOT / "SomedayBox.xcodeproj/project.pbxproj"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    report_path = FIXTURES / "CoreBoxProofReport.json"
    report_bytes = report_path.read_bytes()
    report = json.loads(report_bytes)
    canonical = (json.dumps(report, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    if report_bytes != canonical or report.get("profile") != "pipeline-spike-v1":
        raise SystemExit("core_box_proof_report_invalid")
    if report.get("clips") != ["idle.listen", "capture.deposit", "draw.reveal"]:
        raise SystemExit("core_box_proof_clip_contract_invalid")
    tier_files = {"full": "CoreBoxProofFull.usdz", "lite": "CoreBoxProofLite.usdz"}
    for tier, filename in tier_files.items():
        package = FIXTURES / filename
        if report["tiers"][tier]["sha256"] != digest(package):
            raise SystemExit(f"core_box_proof_digest_mismatch:{tier}")
        if report["tiers"][tier]["byteCount"] != package.stat().st_size:
            raise SystemExit(f"core_box_proof_size_mismatch:{tier}")
    source = GENERATED.read_text(encoding="utf-8")
    expected = {
        "reportSHA256": hashlib.sha256(report_bytes).hexdigest(),
        "fullTierSHA256": report["tiers"]["full"]["sha256"],
        "liteTierSHA256": report["tiers"]["lite"]["sha256"],
    }
    for name, value in expected.items():
        if re.search(rf'static let {name} = "{value}"', source) is None:
            raise SystemExit(f"core_box_proof_identity_mismatch:{name}")
    project = PROJECT.read_text(encoding="utf-8")
    app_resources = project.split("A70000000000000000000001 /* Resources */ = {", 1)[1].split("\t\t};", 1)[0]
    if "CoreBoxProof" in app_resources:
        raise SystemExit("core_box_proof_in_production_resources")
    print("[core-box proof audit] Proof bytes, identity, and test-only resource boundary passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
