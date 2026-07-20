"""Read-only source validation for the Blender proof character."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view


REQUIRED = {"BoxRoot", "BoxBody", "LidPivot", "LidMesh", "EyeLeftPivot", "EyeLeftMesh", "EyeRightPivot", "EyeRightMesh", "RibbonRoot", "RibbonJoint_01", "RibbonJoint_02", "RibbonJoint_03", "RibbonJoint_04", "RibbonJoint_05", "RibbonTip", "PaperPool", "PaperSpawn", "PaperExit", "PaperDeposit", "PaperReveal", "CurrentPaperAnchor", "MemorySeam", "DecorationRoot", "ShadowReceiver", "Hit_Lid", "Hit_Ribbon", "Hit_Box", "Hit_MemorySeam", "Camera_Default", "Camera_Peek", "Camera_Overview", "Light_Key", "Light_Fill"}
EXPECTED_FLAGS = {"debug": 0, "inspect": 0, "interactive": 0, "optimize": 0, "dont_write_bytecode": 1, "no_user_site": 1, "ignore_environment": 0, "verbose": 0, "bytes_warning": 0, "quiet": 0, "hash_randomization": 0, "isolated": 0, "dev_mode": False, "utf8_mode": 1, "safe_path": False, "warn_default_encoding": 0}


def require_startup_contract() -> None:
    """Reject interpreter drift before inspecting project-owned data."""
    actual = {name: getattr(sys.flags, name) for name in EXPECTED_FLAGS}
    if not __debug__ or actual != EXPECTED_FLAGS:
        raise RuntimeError(f"unexpected Python flags: {actual!r}")
    allowed = {"PYTHONPATH", "PYTHONHOME", "PYTHONUSERBASE", "PYTHONDONTWRITEBYTECODE", "PYTHONHASHSEED", "PYTHONNOUSERSITE"}
    for name, value in os.environ.items():
        if name.startswith("PYTHON") and name not in allowed:
            raise RuntimeError(f"unexpected Python environment key: {name}")
    for name in ("PYTHONPATH", "PYTHONHOME", "PYTHONUSERBASE"):
        if os.environ.get(name) != "":
            raise RuntimeError(f"{name} must be present and empty")


def main() -> None:
    require_startup_contract()
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args(arguments)
    config = json.loads(args.config.read_text(encoding="utf-8"))
    objects = set(bpy.data.objects.keys())
    missing = REQUIRED - objects
    if missing:
        raise RuntimeError(f"missing required objects: {sorted(missing)}")
    collections = {collection.name for collection in bpy.data.collections}
    expected_collections = {"SOURCE_SHARED", "EXPORT_FULL", "EXPORT_LITE"}
    if collections != expected_collections:
        raise RuntimeError(f"unexpected collections: {collections}")
    shared = bpy.data.collections["SOURCE_SHARED"]
    full = bpy.data.collections["EXPORT_FULL"]
    lite = bpy.data.collections["EXPORT_LITE"]
    if shared.name not in {child.name for child in full.children} or shared.name not in {child.name for child in lite.children}:
        raise RuntimeError("SOURCE_SHARED must be a child of both export collections")
    shared_objects = {object.name for object in shared.all_objects}
    full_objects = {object.name for object in full.all_objects}
    lite_objects = {object.name for object in lite.all_objects}
    if full_objects & lite_objects != shared_objects:
        raise RuntimeError("export scopes do not intersect exactly at SOURCE_SHARED")
    if any(f"PaperRest_{index:02d}" not in shared_objects for index in range(10)):
        raise RuntimeError("Lite paper anchors are missing from SOURCE_SHARED")
    if any(f"PaperRest_{index:02d}" not in full_objects or f"PaperRest_{index:02d}" in lite_objects for index in range(10, 24)):
        raise RuntimeError("Full-only paper anchors are not isolated")
    actions = {action.name for action in bpy.data.actions}
    expected_actions = {"idle.listen", "capture.deposit", "draw.reveal"}
    if actions != expected_actions:
        raise RuntimeError(f"unexpected actions: {actions}")
    for name, end in (("idle.listen", 60), ("capture.deposit", 34), ("draw.reveal", 45)):
        clip = bpy.data.actions[name]
        if not clip.slots or not clip.layers or tuple(round(value) for value in clip.frame_range) != (0, end):
            raise RuntimeError(f"{name} lacks the expected motion curve and frame range")
    for name in ("Camera_Default", "Camera_Peek", "Camera_Overview"):
        if bpy.data.objects[name].type != "CAMERA":
            raise RuntimeError(f"{name} is not a camera")
    for name in ("Light_Key", "Light_Fill"):
        if bpy.data.objects[name].type != "LIGHT":
            raise RuntimeError(f"{name} is not a light")
    expected_materials = {"MAT_MaplePaper", "MAT_SageRibbon", "MAT_MossInk", "MAT_InteriorMemory", "MAT_ContactShadow"}
    if not expected_materials.issubset(set(bpy.data.materials.keys())):
        raise RuntimeError("proof material family is incomplete")
    root = bpy.data.objects["BoxRoot"]
    ribbon = bpy.data.objects["RibbonRoot"]
    camera = bpy.data.objects["Camera_Default"]
    ribbon_screen_x = world_to_camera_view(bpy.context.scene, camera, ribbon.matrix_world.translation).x
    eye_screen_x = world_to_camera_view(bpy.context.scene, camera, bpy.data.objects["EyeRightPivot"].matrix_world.translation).x
    report = {
        "collections": sorted(collections), "actions": sorted(actions),
        "boxRootScale": list(root.scale), "ribbonRootTranslation": list(ribbon.location),
        "ribbonRootScreenX": ribbon_screen_x, "rightEyeSafeMaxX": eye_screen_x + 0.025,
        "configAssetVersion": config["assetVersion"],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
