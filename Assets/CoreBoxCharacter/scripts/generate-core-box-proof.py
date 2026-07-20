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
    full_digest, lite_digest = sha256(args.full), sha256(args.lite)
    report = {
        "clips": clips,
        "profile": "pipeline-spike-v1",
        "tiers": {
            "full": {"byteCount": args.full.stat().st_size, "sha256": full_digest},
            "lite": {"byteCount": args.lite.stat().st_size, "sha256": lite_digest},
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
