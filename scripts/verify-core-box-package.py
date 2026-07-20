"""Fail-closed package-member audit for a proof Core Box USDZ."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def expected_members(tier: str) -> set[str]:
    resource = "CoreBoxCharacterFull" if tier == "full" else "CoreBoxCharacterLite"
    return {
        f"{resource}.usdc",
        "0/idle_listen.usda", "0/capture_deposit.usda", "0/draw_reveal.usda",
        "textures/core-box-basecolor.png", "textures/core-box-normal.png", "textures/core-box-roughness.png",
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True, type=Path)
    parser.add_argument("--tier", required=True, choices=("full", "lite"))
    args = parser.parse_args(argv)
    result = subprocess.run(["/usr/bin/usdzip", str(args.package), "--list", "-"], check=False, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        return 66
    members = {line.strip() for line in result.stdout.splitlines() if line.strip()}
    if members != expected_members(args.tier):
        print(f"package_member_mismatch: {sorted(members)!r}", file=sys.stderr)
        return 65
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
