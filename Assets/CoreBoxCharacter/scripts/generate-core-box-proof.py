"""Seal the three-motion Core Box spike as test-only byte-identified evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    """Return the lowercase SHA-256 digest for the exact file bytes."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_json(value: object) -> bytes:
    """Serialize proof evidence without whitespace, time, or checkout metadata."""
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def swift_proof_identity_source(report_digest: str, full_digest: str, lite_digest: str) -> bytes:
    """Generate the test-target identity source from validated hexadecimal digests."""
    digest_pattern = re.compile(r"^[0-9a-f]{64}$")
    for digest in (report_digest, full_digest, lite_digest):
        if digest_pattern.fullmatch(digest) is None:
            raise ValueError(f"invalid_generated_digest: {digest}")
    source = f'''import Foundation

enum CoreBoxProofIdentity {{
    static let profile = "pipeline-spike-v1"
    static let reportSHA256 = "{report_digest}"
    static let fullTierSHA256 = "{full_digest}"
    static let liteTierSHA256 = "{lite_digest}"
}}
'''
    return source.encode("utf-8")


# These transforms are the proof asset's deterministic runtime fallback data.
# Values are relative to the USDZ rest pose, so the report remains portable
# across RealityKit's container entity wrapping.
IDENTITY_TRANSFORM = {"translation": [0.0, 0.0, 0.0], "rotationDegrees": [0.0, 0.0, 0.0], "scale": [1.0, 1.0, 1.0]}


def proof_parentage(required_names: list[str]) -> dict[str, str]:
    """Return the authored public hierarchy with an empty root parent marker."""
    parentage = {name: "BoxRoot" for name in required_names if name != "BoxRoot"}
    parentage["BoxRoot"] = ""
    parentage.update(
        {
            "EyeLeftMesh": "EyeLeftPivot",
            "EyeRightMesh": "EyeRightPivot",
            "LidMesh": "LidPivot",
            "RibbonJoint_01": "RibbonRoot",
            "RibbonJoint_02": "RibbonJoint_01",
            "RibbonJoint_03": "RibbonJoint_02",
            "RibbonJoint_04": "RibbonJoint_03",
            "RibbonJoint_05": "RibbonJoint_04",
            "RibbonTip": "RibbonJoint_05",
        }
    )
    return parentage


def transform(translation: list[float], rotation_degrees: list[float] = [0.0, 0.0, 0.0], scale: list[float] = [1.0, 1.0, 1.0]) -> dict[str, list[float]]:
    """Create a canonical relative Transform keyframe payload."""
    return {"translation": translation, "rotationDegrees": rotation_degrees, "scale": scale}


def runtime_recipe_contract() -> list[dict[str, object]]:
    """Describe the three audited proof motions, including rest and terminal frames."""
    return [
        {
            "name": "idle.listen",
            "durationMilliseconds": 1000,
            "keyframes": [
                {"timeMilliseconds": 0, "entity": "BoxRoot", "transform": IDENTITY_TRANSFORM},
                {"timeMilliseconds": 1000, "entity": "BoxRoot", "transform": transform([0.0, 0.002, 0.0], [0.0, 0.0, 2.0])},
            ],
        },
        {
            "name": "capture.deposit",
            "durationMilliseconds": 560,
            "keyframes": [
                {"timeMilliseconds": 0, "entity": "LidPivot", "transform": IDENTITY_TRANSFORM},
                {"timeMilliseconds": 560, "entity": "LidPivot", "transform": transform([0.0, 0.015, 0.0], [0.0, 0.0, 8.0])},
            ],
        },
        {
            "name": "draw.reveal",
            "durationMilliseconds": 750,
            "keyframes": [
                {"timeMilliseconds": 0, "entity": "PaperReveal", "transform": IDENTITY_TRANSFORM},
                {"timeMilliseconds": 750, "entity": "PaperReveal", "transform": transform([0.0, 0.08, 0.0], [0.0, 0.0, -7.0], [1.02, 1.02, 1.02])},
            ],
        },
    ]


def ribbon_sample_contract() -> list[dict[str, object]]:
    """Describe every controlled ribbon-chain pose at the three frozen samples."""
    names = ["BoxRoot", "RibbonRoot", "RibbonJoint_01", "RibbonJoint_02", "RibbonJoint_03", "RibbonJoint_04", "RibbonJoint_05", "RibbonTip"]
    samples = []
    for progress in [0.0, 0.72, 1.0]:
        transforms = []
        for index, name in enumerate(names):
            # BoxRoot stays fixed; the chain extends right/down with a small, finite bend.
            if name == "BoxRoot":
                value = IDENTITY_TRANSFORM
            else:
                bend = progress * (index * 0.35)
                value = transform([progress * 0.012, -progress * index * 0.001, progress * index * 0.0005], [0.0, bend, 0.0])
            transforms.append({"entity": name, "transform": value})
        samples.append({"progress": progress, "entities": transforms})
    return samples


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--full", required=True, type=Path)
    parser.add_argument("--lite", required=True, type=Path)
    parser.add_argument("--full-output", required=True, type=Path)
    parser.add_argument("--lite-output", required=True, type=Path)
    parser.add_argument("--report-output", required=True, type=Path)
    parser.add_argument("--swift-output", required=True, type=Path)
    args = parser.parse_args(argv)
    config = json.loads(args.config.read_text(encoding="utf-8"))
    clips = config["exportProfiles"]["pipeline-spike-v1"]["clipSelection"]["names"]
    if clips != ["idle.listen", "capture.deposit", "draw.reveal"]:
        raise ValueError("unexpected proof clip selection")
    ribbon_samples = config["parameterizedChannels"][0]["samples"]
    if ribbon_samples != [0.0, 0.72, 1.0]:
        raise ValueError("unexpected proof ribbon samples")
    full_digest, lite_digest = sha256(args.full), sha256(args.lite)
    report = {
        "animationEncoding": config["animationEncoding"],
        "clips": clips,
        "profile": "pipeline-spike-v1",
        "requiredEntityNames": config["requiredEntities"],
        "parentByEntity": proof_parentage(config["requiredEntities"]),
        "rootRestTransform": IDENTITY_TRANSFORM,
        "runtimeTransformRecipes": runtime_recipe_contract(),
        "ribbonSamples": ribbon_sample_contract(),
        "ribbonSampleProgress": ribbon_samples,
        "tiers": {
            "full": {
                "byteCount": args.full.stat().st_size,
                "paperRestCount": config["tiers"]["full"]["paperRestCount"],
                "sha256": full_digest,
            },
            "lite": {
                "byteCount": args.lite.stat().st_size,
                "paperRestCount": config["tiers"]["lite"]["paperRestCount"],
                "sha256": lite_digest,
            },
        },
    }
    report_bytes = canonical_json(report)
    report_digest = hashlib.sha256(report_bytes).hexdigest()
    for output in (args.full_output, args.lite_output, args.report_output, args.swift_output):
        output.parent.mkdir(parents=True, exist_ok=True)
    # The source packages have already passed usdchecker and package-member audit.
    shutil.copyfile(args.full, args.full_output)
    shutil.copyfile(args.lite, args.lite_output)
    args.report_output.write_bytes(report_bytes)
    args.swift_output.write_bytes(swift_proof_identity_source(report_digest, full_digest, lite_digest))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
