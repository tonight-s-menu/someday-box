"""Normalize Blender's static USDA material scope for Core Box packaging."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from pxr import Sdf, Usd, UsdGeom

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from core_box_usda import canonicalize_sdf_layer, canonicalize_usda


def compose(source: Path, output: Path) -> None:
    """Move Blender's raw material scope beneath the one public root."""
    source_layer = Sdf.Layer.FindOrOpen(str(source))
    if source_layer is None:
        raise RuntimeError(f"cannot open source layer: {source}")
    output.parent.mkdir(parents=True, exist_ok=True)
    output_layer = Sdf.Layer.CreateNew(str(output))
    output_layer.TransferContent(source_layer)
    stage = Usd.Stage.Open(output_layer)
    root = stage.GetPrimAtPath("/BoxRoot")
    materials = stage.GetPrimAtPath("/_materials")
    if not root.IsValid() or not materials.IsValid():
        raise RuntimeError("expected /BoxRoot and /_materials")
    edit = Sdf.BatchNamespaceEdit()
    edit.Add("/_materials", "/BoxRoot/Materials")
    if not output_layer.Apply(edit):
        raise RuntimeError("material namespace edit failed")
    # Sdf namespace edits do not retarget authored relationship and shader
    # connection paths. The exported layer has one closed, known prefix, so
    # rewrite only that exact path token before reopening the stage.
    content = output_layer.ExportToString()
    if "</_materials" not in content:
        raise RuntimeError("material references were unexpectedly absent")
    if not output_layer.ImportFromString(content.replace("</_materials", "</BoxRoot/Materials")):
        raise RuntimeError("material reference rewrite failed")
    stage = Usd.Stage.Open(output_layer)
    UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
    UsdGeom.SetStageMetersPerUnit(stage, 1.0)
    children = [prim.GetPath().pathString for prim in stage.GetPseudoRoot().GetChildren()]
    if children != ["/BoxRoot"] or not stage.GetPrimAtPath("/BoxRoot/Materials").IsValid():
        raise RuntimeError(f"normalized hierarchy is invalid: {children}")
    if stage.GetPrimAtPath("/_materials").IsValid():
        raise RuntimeError("raw material scope remains")
    if "</_materials" in output_layer.ExportToString():
        raise RuntimeError("raw material reference remains")
    canonicalize_sdf_layer(output_layer)
    output_layer.Save()
    canonicalize_usda(output)


def main() -> None:
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(arguments)
    compose(args.source.resolve(), args.output.resolve())


if __name__ == "__main__":
    main()
