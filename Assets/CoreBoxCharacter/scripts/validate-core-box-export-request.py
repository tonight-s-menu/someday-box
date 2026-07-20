"""Validate the closed export request before Blender opens source data."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def canonical_json(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def validate(config_path: Path, output: Path, profile_name: str) -> dict[str, object]:
    if not config_path.is_file() or not output.is_absolute() or not output.is_dir():
        raise ValueError("config must exist and output must be an absolute existing directory")
    config = json.loads(config_path.read_text(encoding="utf-8"))
    profiles = config.get("exportProfiles")
    if not isinstance(profiles, dict) or profile_name not in profiles:
        raise ValueError("unknown export profile")
    profile = profiles[profile_name]
    selection = profile.get("clipSelection", {})
    clips = config.get("clips", [])
    configured = {clip["name"] for clip in clips}
    names = sorted(configured if selection.get("mode") == "allConfigured" else selection.get("names", []))
    if not names or set(names) - configured:
        raise ValueError("profile clip selection is invalid")
    dimensions = profile.get("textureDimensions", {})
    if set(dimensions) != {"full", "lite"}:
        raise ValueError("profile must declare both tier texture dimensions")
    for tier, maps in dimensions.items():
        if set(maps) != {"basecolor", "normal", "roughness"} or any(not isinstance(size, int) or size <= 0 for size in maps.values()):
            raise ValueError(f"invalid texture dimensions for {tier}")
    return {"profile": profile_name, "tiers": ["full", "lite"], "clips": names, "textureDimensions": dimensions}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--profile")
    arguments, unknown = parser.parse_known_args(argv)
    if unknown or not arguments.config or not arguments.output or not arguments.profile:
        return 64
    try:
        print(canonical_json(validate(arguments.config, arguments.output, arguments.profile)))
    except (OSError, ValueError, TypeError, KeyError, AttributeError, json.JSONDecodeError) as error:
        print(f"invalid_export_request: {error}", file=sys.stderr)
        return 64
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
