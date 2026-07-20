"""Normalize only the timestamp metadata in a USDZ ZIP container."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from core_box_usdz import normalize_zip_timestamps


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True, type=Path)
    args = parser.parse_args(argv)
    args.package.write_bytes(normalize_zip_timestamps(args.package.read_bytes()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
