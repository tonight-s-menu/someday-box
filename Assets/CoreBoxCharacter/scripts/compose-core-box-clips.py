"""Attach the three proof action layers as standard USD clip sets."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from pxr import Sdf, Usd


def compose(base: Path, output: Path, clips: list[dict[str, object]]) -> None:
    """Copy the normalized base and bind each action under its own clip set."""
    source = Sdf.Layer.FindOrOpen(str(base))
    if source is None:
        raise RuntimeError(f"cannot open base layer: {base}")
    output.parent.mkdir(parents=True, exist_ok=True)
    layer = Sdf.Layer.CreateNew(str(output))
    layer.TransferContent(source)
    stage = Usd.Stage.Open(layer)
    stage.SetTimeCodesPerSecond(1000)
    stage.SetFramesPerSecond(60)
    root = stage.GetPrimAtPath("/BoxRoot")
    if not root.IsValid():
        raise RuntimeError("base stage lacks /BoxRoot")
    names: dict[str, str] = {}
    for index, clip in enumerate(clips):
        name = clip["name"]
        token = name.replace(".", "_")
        asset = Sdf.AssetPath(f"clips/{token}.usda")
        api = Usd.ClipsAPI(root)
        api.SetClipAssetPaths([asset], token)
        api.SetClipPrimPath("/BoxRoot", token)
        api.SetClipActive([(0.0, 0)], token)
        api.SetClipTimes([(0.0, 0.0), (float(clip["durationMilliseconds"]), float(clip["authoringFrameCount"]))], token)
        names[token] = name
    root.SetCustomDataByKey("coreBoxAnimationNames", names)
    layer.Save()


def main() -> None:
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--config", required=True, type=Path)
    args = parser.parse_args(arguments)
    config = json.loads(args.config.read_text(encoding="utf-8"))
    selected = config["exportProfiles"]["pipeline-spike-v1"]["clipSelection"]["names"]
    by_name = {clip["name"]: clip for clip in config["clips"]}
    compose(args.base.resolve(), args.output.resolve(), [by_name[name] for name in selected])


if __name__ == "__main__":
    main()
