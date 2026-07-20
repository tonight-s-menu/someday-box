#!/usr/bin/env python3
"""Create the external Core Box candidate evidence manifest.

The checked-in repository intentionally does not contain a release claim.  A
candidate manifest is generated only from a sealed asset set, a signed archive,
and immutable Simulator/audit evidence supplied by the caller.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from core_box_tree_digest import evidence_tree_digest  # noqa: E402

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"json_object_required:{path}")
    return value


def require_sha(value: object, label: str) -> str:
    if not isinstance(value, str) or SHA256_RE.fullmatch(value) is None:
        raise ValueError(f"invalid_sha256:{label}")
    return value


def archive_metadata(archive: Path) -> dict:
    info_path = archive / "Info.plist"
    app = archive / "Products" / "Applications" / "SomedayBox.app"
    app_info_path = app / "Info.plist"
    executable = app / "SomedayBox"
    if not info_path.is_file() or not app_info_path.is_file() or not executable.is_file():
        raise ValueError("archive_metadata_missing")
    with info_path.open("rb") as stream:
        archive_info = plistlib.load(stream)
    with app_info_path.open("rb") as stream:
        app_info = plistlib.load(stream)
    verification = subprocess.run(
        ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if verification.returncode != 0:
        raise ValueError("archive_is_not_strictly_signed")
    details = subprocess.run(
        ["/usr/bin/codesign", "-dv", "--verbose=4", str(executable)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if details.returncode != 0:
        raise ValueError("archive_signature_details_unavailable")
    signature: dict[str, str] = {}
    for line in details.stderr.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            if key in {"Identifier", "TeamIdentifier", "CDHash", "Authority"}:
                signature[key] = value
    for key in ("Identifier", "CDHash"):
        if not signature.get(key):
            raise ValueError(f"archive_signature_field_missing:{key}")
    return {
        "bundleIdentifier": app_info.get("CFBundleIdentifier"),
        "marketingVersion": app_info.get("CFBundleShortVersionString"),
        "buildNumber": app_info.get("CFBundleVersion"),
        "archiveName": archive_info.get("Name"),
        "signature": signature,
    }


def build_manifest(args: argparse.Namespace) -> dict:
    source_root = args.source_root.resolve()
    manifest_path = source_root / "Resources" / "CoreBoxAssetManifest.json"
    full_path = source_root / "Resources" / "CoreBoxCharacterFull.usdz"
    lite_path = source_root / "Resources" / "CoreBoxCharacterLite.usdz"
    identity_path = source_root / "Generated" / "CoreBoxAssetIdentity.generated.swift"
    for path in (manifest_path, full_path, lite_path, identity_path):
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"sealed_production_input_missing:{path}")

    manifest = read_json(manifest_path)
    for key in ("assetVersion", "authoringTreeSHA256", "animationEncoding", "clips", "tiers"):
        if key not in manifest:
            raise ValueError(f"production_manifest_missing:{key}")
    manifest_digest = sha256(manifest_path)
    full_digest = sha256(full_path)
    lite_digest = sha256(lite_path)
    if manifest.get("manifestSHA256", manifest_digest) != manifest_digest:
        raise ValueError("production_manifest_digest_mismatch")
    for tier_name, digest in (("full", full_digest), ("lite", lite_digest)):
        tier = manifest["tiers"].get(tier_name)
        if not isinstance(tier, dict) or tier.get("sha256") != digest:
            raise ValueError(f"production_tier_digest_mismatch:{tier_name}")
        if tier.get("byteCount") != (full_path if tier_name == "full" else lite_path).stat().st_size:
            raise ValueError(f"production_tier_byte_count_mismatch:{tier_name}")

    repro = read_json(args.repro_report)
    asset_audit = read_json(args.asset_audit_report)
    if repro.get("status") not in {"pass", "passed"}:
        raise ValueError("reproducibility_evidence_not_pass")
    if asset_audit.get("status") not in {"pass", "passed"}:
        raise ValueError("asset_audit_evidence_not_pass")
    archive_info = archive_metadata(args.archive)
    archive_digest = evidence_tree_digest(args.archive, "xcarchive-tree-sha256-v1")
    result_digest = evidence_tree_digest(args.xcresult, "xcresult-tree-sha256-v1")
    candidate_sha = args.candidate_sha
    if SHA256_RE.fullmatch(candidate_sha) is None:
        raise ValueError("candidate_sha_must_be_64_lowercase_hex")

    return {
        "manifestVersion": 2,
        "featureStatus": "shipped-in-candidate-release-blocked",
        "candidateSHA": candidate_sha,
        "coreBoxRendererVersion": "core-box-renderer-v2",
        "coreBoxAssetVersion": manifest["assetVersion"],
        "coreBoxAssetIdentity": {
            "manifestSHA256": manifest_digest,
            "fullTierSHA256": full_digest,
            "liteTierSHA256": lite_digest,
            "authoringTreeSHA256": require_sha(manifest["authoringTreeSHA256"], "authoringTreeSHA256"),
        },
        "coreBoxInteractionVersion": "core-box-interaction-v2",
        "coreBoxAnimationTimingVersion": "core-box-timing-v2",
        "coreBoxRendererDefault": "automatic",
        "coreBoxRendererChoices": ["automatic", "full3D", "simplified2D"],
        "coreBoxRendererTiers": ["full3D", "lite3D", "swiftUI2D"],
        "coreBoxMotionModes": ["normal", "quick", "reduced"],
        "coreBoxFallbackPolicyVersion": "core-box-fallback-v2",
        "committedOutcomeVersion": "core-box-outcome-v2",
        "preferenceNamespace": "core-box-presentation-v2",
        "drawContextVersion": "time-context-v2",
        "selectionPolicyVersion": "time-context-v2",
        "schemaVersion": "3.0.0",
        "backupFormatVersion": 3,
        "backupCanonicalizationVersion": 1,
        "generationDigestVersion": "generation-digest-v3",
        "evidence": {
            "reproducibility": repro,
            "assetAudit": asset_audit,
            "simulatorResult": {
                "treeDigestVersion": "xcresult-tree-sha256-v1",
                "treeSHA256": result_digest,
            },
        },
        "archive": {
            **archive_info,
            "treeDigestVersion": "xcarchive-tree-sha256-v1",
            "treeSHA256": archive_digest,
        },
        "releaseGate": {
            "localSourceAndSimulator": "pass",
            "physicalDevicePerformance": "not-run",
            "manualAssistiveTechnology": "not-run",
            "runtimeNetworkPrivacy": "not-run",
            "signedPackagedCandidate": "pass",
            "decision": "blocked",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--repro-report", type=Path, required=True)
    parser.add_argument("--asset-audit-report", type=Path, required=True)
    parser.add_argument("--xcresult", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        manifest = build_manifest(args)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_name(f".{args.output.name}.tmp")
        temporary.write_text(
            json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
            encoding="utf-8",
        )
        temporary.replace(args.output)
    except (OSError, ValueError, json.JSONDecodeError, plistlib.InvalidFileException) as error:
        print(f"[core-box candidate manifest] FAIL: {error}", file=sys.stderr)
        return 1
    print(f"[core-box candidate manifest] wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
